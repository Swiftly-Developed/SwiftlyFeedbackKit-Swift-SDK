import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// UI01 phase 06 — the pure, all-platform half of the translation infrastructure:
/// cache invalidation semantics, one-source-per-batch grouping, the detector's
/// short-text/confidence gates, and the clientIdentifier round-trip.
///
/// Pure types only: no Translation framework, no `SwiftlyFeedback.config` mutation,
/// parallel-safe. The `FeedbackTranslator` itself is exercised only for compilation here —
/// its runtime behaviour needs a framework-owned `TranslationSession` that does not exist
/// off-device, and nothing calls it until phase 07.
@Suite struct TranslationInfrastructureTests {

    private static func makeUnit(
        itemID: UUID = UUID(),
        field: TranslatableField = .title,
        sourceText: String = "Bitte fügt einen Dunkelmodus hinzu",
        sourceLanguage: Locale.Language = Locale.Language(identifier: "de")
    ) -> TranslatableUnit {
        TranslatableUnit(itemID: itemID, field: field, sourceText: sourceText, sourceLanguage: sourceLanguage)
    }

    // MARK: - TranslationCache

    @Test("Cache round-trip: store then lookup with the same source text returns the translation")
    func cacheRoundtrip() {
        var cache = TranslationCache()
        let unit = Self.makeUnit()
        let target = Locale.Language(identifier: "en")

        #expect(cache.lookup(itemID: unit.itemID, field: unit.field, target: target, sourceText: unit.sourceText) == nil)
        cache.store(unit: unit, target: target, translatedText: "Please add a dark mode")
        #expect(cache.lookup(itemID: unit.itemID, field: unit.field, target: target, sourceText: unit.sourceText) == "Please add a dark mode")
    }

    @Test("Changed source text misses AND evicts — the original fingerprint cannot resurrect the entry")
    func cacheContentChangeMissesAndEvicts() {
        var cache = TranslationCache()
        let unit = Self.makeUnit()
        let target = Locale.Language(identifier: "en")
        cache.store(unit: unit, target: target, translatedText: "Please add a dark mode")

        // The item's text changed under the cached translation: miss.
        #expect(cache.lookup(itemID: unit.itemID, field: unit.field, target: target, sourceText: "Ganz anderer Text") == nil)
        // And the stale entry was evicted, so even the ORIGINAL text now misses —
        // eviction, not a mere fingerprint mismatch.
        #expect(cache.lookup(itemID: unit.itemID, field: unit.field, target: target, sourceText: unit.sourceText) == nil)
    }

    @Test("invalidate(itemID:) drops every field of that item and leaves other items intact")
    func cacheInvalidateSingleItem() {
        var cache = TranslationCache()
        let target = Locale.Language(identifier: "en")
        let doomedID = UUID()
        let doomedTitle = Self.makeUnit(itemID: doomedID, field: .title)
        let doomedDescription = Self.makeUnit(itemID: doomedID, field: .description, sourceText: "Der Dunkelmodus fehlt noch")
        let survivor = Self.makeUnit(field: .title, sourceText: "Il manque le mode sombre", sourceLanguage: Locale.Language(identifier: "fr"))
        cache.store(unit: doomedTitle, target: target, translatedText: "t1")
        cache.store(unit: doomedDescription, target: target, translatedText: "t2")
        cache.store(unit: survivor, target: target, translatedText: "t3")

        cache.invalidate(itemID: doomedID)

        #expect(cache.lookup(itemID: doomedID, field: .title, target: target, sourceText: doomedTitle.sourceText) == nil)
        #expect(cache.lookup(itemID: doomedID, field: .description, target: target, sourceText: doomedDescription.sourceText) == nil)
        #expect(cache.lookup(itemID: survivor.itemID, field: .title, target: target, sourceText: survivor.sourceText) == "t3")
    }

    @Test("invalidateAll empties the cache")
    func cacheInvalidateAll() {
        var cache = TranslationCache()
        let target = Locale.Language(identifier: "en")
        let a = Self.makeUnit()
        let b = Self.makeUnit(field: .commentText, sourceText: "Un commentaire en français", sourceLanguage: Locale.Language(identifier: "fr"))
        cache.store(unit: a, target: target, translatedText: "ta")
        cache.store(unit: b, target: target, translatedText: "tb")

        cache.invalidateAll()

        #expect(cache.lookup(itemID: a.itemID, field: a.field, target: target, sourceText: a.sourceText) == nil)
        #expect(cache.lookup(itemID: b.itemID, field: b.field, target: target, sourceText: b.sourceText) == nil)
    }

    // MARK: - TranslationBatch

    @Test("Batches group mixed sources one-source-per-batch, in deterministic source order")
    func batchGroupingIsDeterministic() {
        let target = Locale.Language(identifier: "en")
        let fr1 = Self.makeUnit(sourceText: "Le mode sombre serait super", sourceLanguage: Locale.Language(identifier: "fr"))
        let de1 = Self.makeUnit(sourceText: "Bitte fügt einen Dunkelmodus hinzu", sourceLanguage: Locale.Language(identifier: "de"))
        let fr2 = Self.makeUnit(field: .description, sourceText: "Vraiment indispensable", sourceLanguage: Locale.Language(identifier: "fr"))
        let es1 = Self.makeUnit(sourceText: "El modo oscuro sería genial", sourceLanguage: Locale.Language(identifier: "es"))

        let batches = TranslationBatch.batches(from: [fr1, de1, fr2, es1], target: target)

        #expect(batches.map { $0.source.minimalIdentifier } == ["de", "es", "fr"])
        #expect(batches.map { $0.units.count } == [1, 1, 2])
        #expect(batches.allSatisfy { $0.target == target })
        #expect(batches[2].units.allSatisfy { $0.sourceLanguage == Locale.Language(identifier: "fr") })
    }

    @Test("Units already in the target language are dropped, not batched")
    func batchDropsTargetEqualUnits() {
        let target = Locale.Language(identifier: "de")
        let alreadyTarget = Self.makeUnit(sourceLanguage: Locale.Language(identifier: "de"))
        let translatable = Self.makeUnit(sourceText: "Dark mode would be great", sourceLanguage: Locale.Language(identifier: "en"))

        let batches = TranslationBatch.batches(from: [alreadyTarget, translatable], target: target)

        #expect(batches.count == 1)
        #expect(batches[0].source == Locale.Language(identifier: "en"))
        #expect(batches[0].units == [translatable])

        // All-target-equal input produces zero batches.
        #expect(TranslationBatch.batches(from: [alreadyTarget], target: target).isEmpty)
    }

    // MARK: - SourceLanguageDetector

    @Test("A long German paragraph is confidently detected as de")
    func detectorRecognizesGerman() {
        let paragraph = """
        Es wäre wirklich großartig, wenn die App endlich einen Dunkelmodus bekommen würde. \
        Abends ist der helle Hintergrund sehr anstrengend für die Augen, und viele andere \
        Anwendungen bieten diese Möglichkeit schon seit Jahren an.
        """
        let detected = SourceLanguageDetector.detect(paragraph)
        #expect(detected?.minimalIdentifier == "de")
    }

    @Test("A three-word string is below the short-text gate and yields nil")
    func detectorRejectsShortText() {
        #expect(SourceLanguageDetector.detect("Fix this") == nil)
        #expect(SourceLanguageDetector.detect("ok") == nil)
    }

    @Test("Whitespace-only input yields nil")
    func detectorRejectsWhitespace() {
        #expect(SourceLanguageDetector.detect("") == nil)
        #expect(SourceLanguageDetector.detect("   \n\t   \n      ") == nil)
    }

    // MARK: - clientIdentifier round-trip

    @Test("clientIdentifier parses back to the exact itemID and field")
    func clientIdentifierRoundTrip() {
        let unit = Self.makeUnit(field: .rejectionReason)
        let parsed = TranslatableUnit.parse(clientIdentifier: unit.clientIdentifier)
        #expect(parsed?.itemID == unit.itemID)
        #expect(parsed?.field == .rejectionReason)
    }

    @Test("Malformed clientIdentifiers parse to nil")
    func clientIdentifierRejectsMalformed() {
        #expect(TranslatableUnit.parse(clientIdentifier: "") == nil)
        #expect(TranslatableUnit.parse(clientIdentifier: "not-a-uuid|title") == nil)
        #expect(TranslatableUnit.parse(clientIdentifier: "\(UUID().uuidString)|notAField") == nil)
        #expect(TranslatableUnit.parse(clientIdentifier: UUID().uuidString) == nil)
    }
}
