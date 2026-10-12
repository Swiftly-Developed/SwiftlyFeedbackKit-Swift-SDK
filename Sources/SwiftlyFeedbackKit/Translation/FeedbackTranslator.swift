import Foundation
import Observation

// The compound guard is deliberate: the visionOS SDK ships a STUB Translation.framework
// whose every symbol is `@available(visionOS, unavailable)`, so a bare
// `#if canImport(Translation)` evaluates TRUE on visionOS and compiles the wrong arm.
// Both arms declare the identical platform-neutral surface, so phase-07 call sites need
// no platform forks.
#if canImport(Translation) && (os(iOS) || os(macOS))
import Translation

/// Drives on-device translation of feedback content, batch by batch.
///
/// The `TranslationSession` is framework-owned: it is only valid inside the view's
/// `.translationTask` action closure and is **never stored** here — ``run(session:)``
/// receives it as a parameter for the duration of one batch. The translator only holds
/// the ``configuration`` that *causes* the view to obtain a session, the pending batch
/// queue, and the in-memory cache of results. Assigning the next batch's configuration
/// re-fires the view's translation task, so a mixed-language list runs as N sequential
/// configuration changes — the one-source-per-batch constraint made mechanical.
@MainActor
@Observable
final class FeedbackTranslator {

    /// In-memory results, exposed via ``translation(for:field:target:sourceText:)``.
    private(set) var cache = TranslationCache()

    /// Pending batches; the head batch is the one ``configuration`` currently describes.
    private var queue: [TranslationBatch] = []

    /// Whether `prepareTranslation()` has run for this translator instance.
    /// Prepare-once-on-first-appear: the system download sheet must never appear
    /// mid-scroll, and never more than once per screen entry.
    private var hasPrepared = false

    /// The configuration the owning view feeds to `.translationTask(_:action:)`.
    /// Non-nil while a batch is pending; assigning a new value re-fires the task.
    private(set) var configuration: TranslationSession.Configuration?

    /// Reports whether the pair can be translated on this device.
    ///
    /// The `translationEnabled` config knob short-circuits here, so callers never
    /// check the knob separately.
    func availability(from source: Locale.Language, to target: Locale.Language) async -> TranslationAvailability {
        guard SwiftlyFeedback.config.translationEnabled else {
            SDKLogger.debug("Translation availability \(source.minimalIdentifier) -> \(target.minimalIdentifier): unsupported (translationEnabled is false)")
            return .unsupported
        }
        let status = await LanguageAvailability().status(from: source, to: target)
        let availability: TranslationAvailability
        switch status {
        case .installed:
            availability = .installed
        case .supported:
            availability = .needsDownload
        case .unsupported:
            availability = .unsupported
        @unknown default:
            availability = .unsupported
        }
        SDKLogger.debug("Translation availability \(source.minimalIdentifier) -> \(target.minimalIdentifier): \(availability)")
        return availability
    }

    /// Queues translation of `units` toward `target`.
    ///
    /// Units already satisfied by the cache are dropped, the rest are grouped one source
    /// language per batch, and the head batch's configuration is published so the owning
    /// view's translation task fires.
    func enqueue(units: [TranslatableUnit], target: Locale.Language) {
        let pending = units.filter { unit in
            cache.lookup(itemID: unit.itemID, field: unit.field, target: target, sourceText: unit.sourceText) == nil
        }
        queue = TranslationBatch.batches(from: pending, target: target)
        SDKLogger.debug("Translation enqueue: \(queue.count) batch(es) [\(queue.map { "\($0.source.minimalIdentifier):\($0.units.count)" }.joined(separator: ", "))] -> \(target.minimalIdentifier)")
        configuration = queue.first.map { TranslationSession.Configuration(source: $0.source, target: $0.target) }
    }

    /// Installs one cache entry without a `TranslationSession`.
    ///
    /// Tests seed a hit through here. The view path (`translation(for:)`) must read it
    /// back without publishing an Observation change.
    func preloadCachedTranslation(
        _ unit: TranslatableUnit,
        target: Locale.Language,
        translatedText: String
    ) {
        cache.store(unit: unit, target: target, translatedText: translatedText)
    }

    /// Cached lookup; `nil` means the caller shows the original text.
    func translation(for itemID: UUID, field: TranslatableField, target: Locale.Language, sourceText: String) -> String? {
        cache.peek(itemID: itemID, field: field, target: target, sourceText: sourceText)
    }

    /// Content-change invalidation for one item (all fields, all targets).
    func invalidate(itemID: UUID) {
        cache.invalidate(itemID: itemID)
    }

    /// Locale-change / refresh invalidation: clears the cache, the queue, and the
    /// published configuration.
    func invalidateAll() {
        cache.invalidateAll()
        queue.removeAll()
        configuration = nil
    }

    /// Translates the head batch using the session the view's `.translationTask` closure
    /// received. The session arrives as a parameter and is never retained.
    ///
    /// Outcomes, three ways: success writes the batch into the cache and advances the
    /// queue (re-firing the task via a new configuration, or nil when drained);
    /// cancellation returns silently with the queue intact — a third outcome, never an
    /// error; any other failure logs at `.warning` (ids only, never feedback text) and
    /// advances past the failed batch so the remaining source languages still run, with
    /// the cache left unfilled so callers fall back to the original text.
    func run(session: TranslationSession) async {
        guard let batch = queue.first else { return }
        do {
            if !hasPrepared {
                try await session.prepareTranslation()
                hasPrepared = true
            }
            let requests = batch.units.map {
                TranslationSession.Request(sourceText: $0.sourceText, clientIdentifier: $0.clientIdentifier)
            }
            let responses = try await session.translations(from: requests)
            for response in responses {
                guard let clientIdentifier = response.clientIdentifier,
                      let (itemID, field) = TranslatableUnit.parse(clientIdentifier: clientIdentifier),
                      let unit = batch.units.first(where: { $0.itemID == itemID && $0.field == field }) else {
                    continue
                }
                cache.store(unit: unit, target: batch.target, translatedText: response.targetText)
            }
            SDKLogger.debug("Translation batch done: \(batch.source.minimalIdentifier) -> \(batch.target.minimalIdentifier), \(batch.units.count) unit(s)")
            advanceQueue()
        } catch is CancellationError {
            // Cancellation is a third outcome: silent return, queue intact, no log.
            return
        } catch {
            if Task.isCancelled { return }
            let itemIDs = Set(batch.units.map { $0.itemID.uuidString }).sorted().joined(separator: ", ")
            SDKLogger.warning("Translation batch failed: \(batch.source.minimalIdentifier) -> \(batch.target.minimalIdentifier), \(batch.units.count) unit(s), itemIDs: [\(itemIDs)] — \(error)")
            advanceQueue()
        }
    }

    private func advanceQueue() {
        guard !queue.isEmpty else {
            configuration = nil
            return
        }
        queue.removeFirst()
        configuration = queue.first.map { TranslationSession.Configuration(source: $0.source, target: $0.target) }
    }
}

#else

/// Platform fallback for targets without a usable Translation framework (visionOS ships
/// only a stub). Declares the full platform-neutral surface so call sites need no forks:
/// every pair is unsupported, enqueue is a no-op, and the cache never fills.
@MainActor
@Observable
final class FeedbackTranslator {

    private(set) var cache = TranslationCache()

    /// Always `.unsupported` here; the knob check is kept first so both arms behave
    /// identically when translation is disabled.
    func availability(from source: Locale.Language, to target: Locale.Language) async -> TranslationAvailability {
        guard SwiftlyFeedback.config.translationEnabled else {
            return .unsupported
        }
        SDKLogger.debug("Translation availability \(source.minimalIdentifier) -> \(target.minimalIdentifier): unsupported (translation framework unavailable on this platform)")
        return .unsupported
    }

    func enqueue(units: [TranslatableUnit], target: Locale.Language) {
        SDKLogger.debug("Translation enqueue ignored (\(units.count) unit(s) -> \(target.minimalIdentifier)): framework unavailable on this platform")
    }

    /// Installs one cache entry without a `TranslationSession`.
    ///
    /// Tests seed a hit through here. The view path (`translation(for:)`) must read it
    /// back without publishing an Observation change.
    func preloadCachedTranslation(
        _ unit: TranslatableUnit,
        target: Locale.Language,
        translatedText: String
    ) {
        cache.store(unit: unit, target: target, translatedText: translatedText)
    }

    /// Cached lookup; the cache never fills on this platform, so this is always `nil`.
    func translation(for itemID: UUID, field: TranslatableField, target: Locale.Language, sourceText: String) -> String? {
        cache.peek(itemID: itemID, field: field, target: target, sourceText: sourceText)
    }

    func invalidate(itemID: UUID) {
        cache.invalidate(itemID: itemID)
    }

    func invalidateAll() {
        cache.invalidateAll()
    }
}

#endif
