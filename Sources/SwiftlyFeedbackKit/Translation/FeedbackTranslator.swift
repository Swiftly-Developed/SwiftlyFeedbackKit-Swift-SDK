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

    /// The device's supported translation targets, held for this translator's lifetime.
    /// `@ObservationIgnored` because nothing observes it — the owning view copies the
    /// result into its own state — and an observed write inside `.task` would invalidate
    /// the view for a value it is about to store itself.
    @ObservationIgnored private var loadedTargets: [Locale.Language]?

    /// The configuration the owning view feeds to `.translationTask(_:action:)`.
    /// Non-nil while a batch is pending; assigning a new value re-fires the task.
    private(set) var configuration: TranslationSession.Configuration?

    /// Reports whether the pair can be translated on this device.
    ///
    /// The `translationEnabled` config knob short-circuits here, so callers never
    /// check the knob separately.
    func availability(from source: Locale.Language, to target: Locale.Language) async -> TranslationAvailability {
        guard SwiftlyFeedback.configuration.translationEnabled else {
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

    /// Every language this device can translate into, read from the framework rather than
    /// from any list in this repository, so a language Apple adds appears without a
    /// release (G2). Read once per translator instance.
    ///
    /// The query is pinned to the same approach the session below is pinned to. From 26.4
    /// the answer varies by approach, so an unpinned query would offer the reader
    /// languages the pinned session cannot serve — and the offered list would still match
    /// what was asked for, so nothing else here would notice.
    ///
    /// 🔴 **The framework query runs OFF this actor, and under a deadline.** Awaiting
    /// `supportedLanguages` from main-actor isolation freezes the app: measured on a physical
    /// iPhone (iOS 26.6), tapping into the feedback list blocked the main thread until iOS
    /// terminated the process with a watchdog `SIGKILL`, while the identical build left alone
    /// ran indefinitely. The query is therefore hopped to the cooperative pool by
    /// `loadSupportedLanguages()` and bounded by `supportedTargetsTimeout`; only the
    /// assignment below returns to this actor. See
    /// `docs/fixes/2026-08-22-feedback-list-freezes-on-device-supportedlanguages.md`.
    func supportedTargets() async -> [Locale.Language] {
        if let loadedTargets { return loadedTargets }
        let targets = await Self.loadSupportedLanguages()
        loadedTargets = targets
        SDKLogger.debug("Translation supported targets: \(targets.count)")
        return targets
    }

    /// How long the framework query may take before this surface gives up on it.
    ///
    /// Timing out yields an empty set, which is a state the product already defines: no
    /// supported targets means the picker does not mount at all (§18), exactly as on a
    /// platform without the framework. A reader on a device that cannot answer in time gets
    /// the untranslated original and no broken control — never a frozen app.
    private static let supportedTargetsTimeout: Duration = .seconds(5)

    /// Reads the device's supported target languages without touching the main actor.
    ///
    /// `nonisolated` is the load-bearing keyword: it puts the framework call on the
    /// cooperative pool, so a query that blocks or never returns costs one pool thread
    /// instead of the main thread. The deadline then bounds the wait.
    private nonisolated static func loadSupportedLanguages() async -> [Locale.Language] {
        await withTaskGroup(of: [Locale.Language]?.self) { group in
            // `LanguageAvailability` is built inside the child. Capturing it from the
            // caller makes the closure `sending` a non-Sendable value, which is a
            // Swift 6 error and the reason this query used to be inlined above.
            group.addTask {
                let availability: LanguageAvailability
                if #available(iOS 26.4, macOS 26.4, *) {
                    availability = LanguageAvailability(preferredStrategy: .lowLatency)
                } else {
                    availability = LanguageAvailability()
                }
                return await availability.supportedLanguages
            }
            group.addTask {
                try? await Task.sleep(for: supportedTargetsTimeout)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            if first == nil {
                SDKLogger.warning("Translation supported-target query timed out; the picker will not mount")
            }
            return first ?? []
        }
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
        configuration = queue.first.map {
            var sessionConfiguration = TranslationSession.Configuration(source: $0.source, target: $0.target)
            // Pin the session's translation approach explicitly rather than inheriting the
            // framework default, which a toolchain bump can change under us (§14.2).
            if #available(iOS 26.4, macOS 26.4, *) {
                sessionConfiguration.preferredStrategy = .lowLatency
            }
            return sessionConfiguration
        }
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
    /// received. The session arrives as a `sending` parameter and is never retained.
    ///
    /// `sending` disconnects the session from the caller's region before this
    /// main-actor method runs. That is what lets the batch hop to the
    /// nonisolated translator under Swift 6 without a public API change: callers
    /// still pass the session and do not use it again after the await.
    ///
    /// Outcomes, three ways: success writes the batch into the cache and advances the
    /// queue (re-firing the task via a new configuration, or nil when drained);
    /// cancellation returns silently with the queue intact — a third outcome, never an
    /// error; any other failure logs at `.warning` (ids only, never feedback text) and
    /// advances past the failed batch so the remaining source languages still run, with
    /// the cache left unfilled so callers fall back to the original text.
    func run(session: sending TranslationSession) async {
        guard let batch = queue.first else { return }
        let shouldPrepare = !hasPrepared
        let target = batch.target
        let units = batch.units
        let payloads = units.map {
            TranslationBatchPayload(sourceText: $0.sourceText, clientIdentifier: $0.clientIdentifier)
        }
        do {
            // The session and its requests stay inside one nonisolated function.
            // Awaiting them here, on the main actor, between uses of `self` is a
            // Swift 6 `sending` error: the session is not `Sendable`.
            let responses = try await Self.translate(
                session: session,
                payloads: payloads,
                shouldPrepare: shouldPrepare
            )
            if shouldPrepare { hasPrepared = true }
            for response in responses {
                guard let clientIdentifier = response.clientIdentifier,
                      let (itemID, field) = TranslatableUnit.parse(clientIdentifier: clientIdentifier),
                      let unit = units.first(where: { $0.itemID == itemID && $0.field == field }) else {
                    continue
                }
                cache.store(unit: unit, target: target, translatedText: response.targetText)
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

    private struct TranslationBatchPayload: Sendable {
        var sourceText: String
        var clientIdentifier: String
    }

    private struct TranslationBatchResult: Sendable {
        var clientIdentifier: String?
        var targetText: String
    }

    /// One batch, off the main actor. Inputs and outputs are `Sendable`; the
    /// session never crosses back to the caller.
    private nonisolated static func translate(
        session: sending TranslationSession,
        payloads: [TranslationBatchPayload],
        shouldPrepare: Bool
    ) async throws -> [TranslationBatchResult] {
        if shouldPrepare {
            try await session.prepareTranslation()
        }
        let requests = payloads.map {
            TranslationSession.Request(sourceText: $0.sourceText, clientIdentifier: $0.clientIdentifier)
        }
        let responses = try await session.translations(from: requests)
        return responses.map {
            TranslationBatchResult(clientIdentifier: $0.clientIdentifier, targetText: $0.targetText)
        }
    }

    private func advanceQueue() {
        guard !queue.isEmpty else {
            configuration = nil
            return
        }
        queue.removeFirst()
        configuration = queue.first.map {
            var sessionConfiguration = TranslationSession.Configuration(source: $0.source, target: $0.target)
            // Pin the session's translation approach explicitly rather than inheriting the
            // framework default, which a toolchain bump can change under us (§14.2).
            if #available(iOS 26.4, macOS 26.4, *) {
                sessionConfiguration.preferredStrategy = .lowLatency
            }
            return sessionConfiguration
        }
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
        guard SwiftlyFeedback.configuration.translationEnabled else {
            return .unsupported
        }
        SDKLogger.debug("Translation availability \(source.minimalIdentifier) -> \(target.minimalIdentifier): unsupported (translation framework unavailable on this platform)")
        return .unsupported
    }

    /// Always empty here: no framework, so no target set. The empty return is what makes
    /// the reader's control **absent** rather than disabled on this platform, which is the
    /// contract `UI00` §18.3 requires.
    func supportedTargets() async -> [Locale.Language] { [] }

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
