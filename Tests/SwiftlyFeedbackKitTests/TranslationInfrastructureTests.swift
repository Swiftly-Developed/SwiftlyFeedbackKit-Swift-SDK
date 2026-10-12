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

    /// A feedback item whose title, description and rejection reason are all confidently
    /// German, so `units(for:target:)` emits one unit per field against a non-German target.
    private static func makeGermanFeedback() -> Feedback {
        Feedback(
            id: UUID(),
            title: "Bitte fügt endlich einen Dunkelmodus für die App hinzu",
            description: "Abends ist der helle Hintergrund sehr anstrengend für die Augen und ein dunkles Design würde wirklich helfen.",
            status: .rejected,
            category: .featureRequest,
            userId: "user-1",
            userEmail: nil,
            voteCount: 1,
            hasVoted: false,
            commentCount: 0,
            createdAt: nil,
            updatedAt: nil,
            rejectionReason: "Dieses Feature passt leider nicht zu unserer aktuellen Produktstrategie."
        )
    }

    /// A confidently German comment.
    private static func makeGermanComment() -> SwiftlyFeedbackKit.Comment {
        Comment(
            id: UUID(),
            content: "Ich stimme vollkommen zu, das würde die App deutlich besser machen.",
            userId: "user-2",
            isAdmin: false,
            createdAt: nil
        )
    }

    /// A confidently Traditional-Chinese comment — the fixture for the writing-system cases.
    /// Measured: `NLLanguageRecognizer` reports `zh-Hant` at 0.999, well clear of both the
    /// 10-character and the 0.6-confidence gate.
    private static func makeTraditionalChineseComment() -> SwiftlyFeedbackKit.Comment {
        Comment(
            id: UUID(),
            content: "希望你們能盡快為這個應用程式增加一個深色模式。晚上使用的時候，明亮的背景對眼睛非常刺激。",
            userId: "user-3",
            isAdmin: false,
            createdAt: nil
        )
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
        #expect(batches.dropFirst(2).first?.units.allSatisfy { $0.sourceLanguage == Locale.Language(identifier: "fr") } == true)
    }

    @Test("Units already in the target language are dropped, not batched")
    func batchDropsTargetEqualUnits() {
        let target = Locale.Language(identifier: "de")
        let alreadyTarget = Self.makeUnit(sourceLanguage: Locale.Language(identifier: "de"))
        let translatable = Self.makeUnit(sourceText: "Dark mode would be great", sourceLanguage: Locale.Language(identifier: "en"))

        let batches = TranslationBatch.batches(from: [alreadyTarget, translatable], target: target)

        #expect(batches.count == 1)
        #expect(batches.first?.source == Locale.Language(identifier: "en"))
        #expect(batches.first?.units == [translatable])

        // All-target-equal input produces zero batches.
        #expect(TranslationBatch.batches(from: [alreadyTarget], target: target).isEmpty)
    }

    // MARK: - TranslationBatch — same-language filtering

    @Test("A region-qualified target drops units whose bare source names the same language")
    func batchDropsRegionQualifiedTargetMatches() {
        let enUS = Locale.Language(identifier: "en_US")
        let en = Self.makeUnit(sourceText: "Dark mode would be great", sourceLanguage: Locale.Language(identifier: "en"))
        let enGB = Self.makeUnit(sourceText: "Dark mode would be great", sourceLanguage: Locale.Language(identifier: "en_GB"))
        let pt = Self.makeUnit(sourceText: "O modo escuro seria ótimo", sourceLanguage: Locale.Language(identifier: "pt"))

        #expect(TranslationBatch.batches(from: [en], target: enUS).isEmpty)
        #expect(TranslationBatch.batches(from: [enGB], target: enUS).isEmpty)
        #expect(TranslationBatch.batches(from: [pt], target: Locale.Language(identifier: "pt_BR")).isEmpty)

        // Same writing system, different region: a region qualification, exactly like the three above.
        let hans = Self.makeUnit(sourceText: "希望你们能尽快为这个应用增加一个深色模式。",
                                 sourceLanguage: Locale.Language(identifier: "zh-Hans"))
        #expect(TranslationBatch.batches(from: [hans], target: Locale.Language(identifier: "zh_CN")).isEmpty)
    }

    @Test("A genuinely different source still batches against a region-qualified target")
    func batchKeepsDifferentLanguageAgainstRegionQualifiedTarget() {
        let enUS = Locale.Language(identifier: "en_US")
        let de = Self.makeUnit()                              // the helper's default is `de`
        let batches = TranslationBatch.batches(from: [de], target: enUS)
        // `.first`, not `batches[0]`: `#expect` does not short-circuit, so a subscript
        // here would TRAP on an empty result and take the whole run's other cases with
        // it instead of recording one red.
        #expect(batches.count == 1)
        #expect(batches.first?.source == Locale.Language(identifier: "de"))
        #expect(batches.first?.units == [de])
    }

    @Test("A different writing system is a different language: Simplified vs Traditional Chinese still batches")
    func batchKeepsUnitsThatDifferOnlyByWritingSystem() {
        let hant = Locale.Language(identifier: "zh-Hant")
        let hans = Self.makeUnit(sourceText: "希望你们能尽快为这个应用增加一个深色模式。",
                                 sourceLanguage: Locale.Language(identifier: "zh-Hans"))
        let batches = TranslationBatch.batches(from: [hans], target: hant)
        // `.first`, not `batches[0]` — see the control case above. This guard is the one
        // §6.1.2's inversion drives red, and a trap there is not a red.
        #expect(batches.count == 1)
        #expect(batches.first?.units == [hans])
    }

    @Test("A unit whose language cannot be identified is dispatched, never silently dropped")
    func batchKeepsCodelessUnitsRatherThanDropping() {
        let codeless = Locale.Language(identifier: "")
        let unit = Self.makeUnit(sourceLanguage: codeless)
        #expect(TranslationBatch.batches(from: [unit], target: codeless).count == 1)
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

    // MARK: - SourceLanguageDetector — applicability against the target

    @Test("A different target language emits one unit per confidently detected field")
    func detectorEmitsUnitsAgainstADifferentTarget() {
        let en = Locale.Language(identifier: "en")
        let units = SourceLanguageDetector.units(for: Self.makeGermanFeedback(), target: en)

        // The control for the two cases below: without it, an implementation that emitted
        // nothing at all would satisfy every `isEmpty` / `== nil` assertion they make.
        #expect(Set(units.map { $0.field }) == [.title, .description, .rejectionReason])
        #expect(units.allSatisfy { $0.sourceLanguage.minimalIdentifier == "de" })
        #expect(SourceLanguageDetector.unit(for: Self.makeGermanComment(), target: en) != nil)
    }

    @Test("A region-qualified target of the same language is not applicable, so no units")
    func detectorDropsRegionQualifiedTargetMatches() {
        let deAT = Locale.Language(identifier: "de_AT")
        #expect(SourceLanguageDetector.units(for: Self.makeGermanFeedback(), target: deAT).isEmpty)
        #expect(SourceLanguageDetector.unit(for: Self.makeGermanComment(), target: deAT) == nil)

        // Same writing system, different region: not applicable.
        #expect(SourceLanguageDetector.unit(for: Self.makeTraditionalChineseComment(),
                                            target: Locale.Language(identifier: "zh_TW")) == nil)
    }

    @Test("The detector keeps a source whose writing system differs from the target's")
    func detectorKeepsDifferentWritingSystem() {
        // Simplified target, Traditional source: a different writing system, so still translatable.
        #expect(SourceLanguageDetector.unit(for: Self.makeTraditionalChineseComment(),
                                            target: Locale.Language(identifier: "zh-Hans")) != nil)
    }

    // MARK: - Locale.Language same-language comparison

    @Test("Same-language comparison ignores region, and an unidentifiable language matches nothing")
    func sameLanguageComparisonSemantics() {
        let en = Locale.Language(identifier: "en")
        let enUS = Locale.Language(identifier: "en_US")
        let de = Locale.Language(identifier: "de")
        let codeless = Locale.Language(identifier: "")

        #expect(en.isSameLanguage(as: enUS))
        #expect(enUS.isSameLanguage(as: en))
        #expect(!de.isSameLanguage(as: enUS))
        // Deliberately NOT reflexive for a language with no code — see the predicate's doc comment.
        #expect(!codeless.isSameLanguage(as: codeless))
        #expect(!codeless.isSameLanguage(as: en))
    }

    @Test("Same language code, different writing system, is not the same language")
    func differentWritingSystemIsNotTheSameLanguage() {
        let hans = Locale.Language(identifier: "zh-Hans")
        let hant = Locale.Language(identifier: "zh-Hant")

        #expect(!hans.isSameLanguage(as: hant))
        #expect(!hant.isSameLanguage(as: hans))
        // Same writing system, different region: still the same language.
        #expect(hans.isSameLanguage(as: Locale.Language(identifier: "zh_CN")))
        #expect(hant.isSameLanguage(as: Locale.Language(identifier: "zh_TW")))
        // Every locale this product ships is unaffected: same code, same writing system, drops.
        #expect(Locale.Language(identifier: "pt").isSameLanguage(as: Locale.Language(identifier: "pt_BR")))
        #expect(Locale.Language(identifier: "en_GB").isSameLanguage(as: Locale.Language(identifier: "en_US")))
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
