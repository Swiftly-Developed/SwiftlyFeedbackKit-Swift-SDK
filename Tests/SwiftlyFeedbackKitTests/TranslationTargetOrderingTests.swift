import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `TRANSLATION01` phase 03 — the order a reader meets the device's target languages in.
///
/// Every case hands the reader's own language list in as a fixture and never lets the
/// argument default: the default reads the host's system list, which on this workstation
/// is a single non-English entry, and a case that takes it passes vacuously on the machine
/// it was written on. Same rule for the display locale: every case names one, and none
/// reads the host's.
///
/// ⚠️ The supported sets below are **stand-ins**. The contents of the framework's real
/// array are unverified until the device walk, and nothing here depends on them: the two
/// criterion cases at the bottom assert the result is a *pure function* of whatever array
/// arrives, which is the substance of "the picker's contents equal the framework's set".
@Suite struct TranslationTargetOrderingTests {

    private static let tenLanguages: [Locale.Language] = [
        "ar", "de", "en-GB", "en-US", "fr", "ja", "pt-BR", "pt-PT", "zh-Hans", "zh-Hant"
    ].map { Locale.Language(identifier: $0) }

    private static let english = Locale(identifier: "en_US")

    @Test("A British-English reader meets British English first and plain English second")
    func britishReaderMeetsBothTiersInOrder() throws {
        let result = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages,
            preferred: [Locale(identifier: "en_GB")],
            displayLocale: Self.english
        )

        // Exact match outranks same-language match: both tiers exercised in one case.
        #expect(result.first == Locale.Language(identifier: "en-GB"))
        #expect(result.dropFirst().first == Locale.Language(identifier: "en-US"))
    }

    @Test("An Austrian-German reader meets German first, which an exact match alone would miss")
    func austrianReaderMeetsGerman() throws {
        let austrian = Locale(identifier: "de_AT")
        // Falsification of the second tier: nothing in the set is an exact match for this
        // reader, so a one-tier implementation hoists nothing and reds here.
        #expect(!Self.tenLanguages.contains { austrian.language.isEquivalent(to: $0) })

        let result = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages,
            preferred: [austrian],
            displayLocale: Self.english
        )

        #expect(result.first == Locale.Language(identifier: "de"))
    }

    @Test("A Traditional-Chinese reader is not offered Simplified Chinese first")
    func traditionalChineseReaderDoesNotHoistSimplified() throws {
        let result = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages,
            preferred: [Locale(identifier: "zh_TW")],
            displayLocale: Self.english
        )

        #expect(result.first == Locale.Language(identifier: "zh-Hant"))

        // A writing system is a real difference: Simplified Chinese falls into the
        // alphabetical tail behind an unrelated language rather than being hoisted.
        let simplified = try #require(result.firstIndex(of: Locale.Language(identifier: "zh-Hans")))
        let arabic = try #require(result.firstIndex(of: Locale.Language(identifier: "ar")))
        #expect(simplified > arabic)
    }

    @Test("A reader's first language outranks their second")
    func firstReaderLanguageOutranksTheSecond() throws {
        let result = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages,
            preferred: [Locale(identifier: "fr_FR"), Locale(identifier: "de_DE")],
            displayLocale: Self.english
        )

        let french = try #require(result.firstIndex(of: Locale.Language(identifier: "fr")))
        let german = try #require(result.firstIndex(of: Locale.Language(identifier: "de")))
        let arabic = try #require(result.firstIndex(of: Locale.Language(identifier: "ar")))
        #expect(french < german)
        #expect(german < arabic)
    }

    @Test("With no reader languages the order is alphabetical under the display locale, not under English")
    func alphabeticalOrderFollowsTheDisplayLocale() throws {
        let inEnglish = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages,
            preferred: [],
            displayLocale: Self.english
        )
        let inGerman = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages,
            preferred: [],
            displayLocale: Locale(identifier: "de_DE")
        )

        #expect(inEnglish.first == Locale.Language(identifier: "ar"))
        // Non-vacuity for the locale-aware comparison: the same input under a different
        // display locale produces a different order, because German's exonyms sort
        // differently from English's.
        #expect(inEnglish != inGerman)
        #expect(Set(inEnglish) == Set(inGerman))
    }

    @Test("A language with no localized name is dropped rather than rendered as a raw code")
    func namelessLanguagesAreDropped() throws {
        let input = [Locale.Language(identifier: "zzz"), Locale.Language(identifier: "de")]
        #expect(input[0].localizedTargetName(in: Self.english) == nil)

        let result = TranslationTargetOrdering.ordered(
            supported: input,
            preferred: [],
            displayLocale: Self.english
        )

        #expect(result == [Locale.Language(identifier: "de")])
    }

    @Test("Identical inputs produce identical output — the tail-break makes the sort total")
    func orderingIsDeterministic() throws {
        let first = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages,
            preferred: [Locale(identifier: "en_GB")],
            displayLocale: Self.english
        )
        let second = TranslationTargetOrdering.ordered(
            supported: Self.tenLanguages.reversed(),
            preferred: [Locale(identifier: "en_GB")],
            displayLocale: Self.english
        )

        #expect(first == second)
    }

    @Test("The result is a permutation of the nameable members of whatever array arrives")
    func resultIsASubsetThatLosesNothingNameable() throws {
        // The criterion says the picker's contents equal the framework's supported set.
        // That has to be expressed as a property, because the array's contents are
        // unverified — so: invent nothing, lose nothing that has a name.
        let input = Self.tenLanguages + [Locale.Language(identifier: "zzz")]

        let result = TranslationTargetOrdering.ordered(
            supported: input,
            preferred: [Locale(identifier: "ja_JP")],
            displayLocale: Self.english
        )

        #expect(Set(result).isSubset(of: Set(input)))
        #expect(result.count == input.filter { $0.localizedTargetName(in: Self.english) != nil }.count)
        #expect(Set(result).count == result.count)
    }

    @Test("""
    Two entries the preference store cannot tell apart collapse to a single row, \
    first occurrence winning
    """)
    func equivalentEntriesCollapseToOneRow() throws {
        let bare = Locale.Language(identifier: "uz")
        let latin = Locale.Language(identifier: "uz-Latn")

        // The premise, measured rather than assumed: two unequal values that the store's
        // matcher calls one language, and that carry the same localized name — so
        // undeduplicated they are two indistinguishable rows, not a visible choice.
        #expect(bare != latin)
        #expect(bare.isEquivalent(to: latin))
        #expect(bare.maximalIdentifier == latin.maximalIdentifier)
        #expect(bare.localizedTargetName(in: Self.english) != nil)
        #expect(bare.localizedTargetName(in: Self.english) == latin.localizedTargetName(in: Self.english))

        let result = TranslationTargetOrdering.ordered(
            supported: [bare, latin, Locale.Language(identifier: "de")],
            preferred: [],
            displayLocale: Self.english
        )

        #expect(result.count == 2)
        // First occurrence wins, which is the member the store's own search returns —
        // so the row the reader picks is the row that comes back after a relaunch.
        #expect(result.contains(bare))
        #expect(!result.contains(latin))
    }

    @Test("A difference in writing system is not a duplicate — Simplified and Traditional both survive")
    func differentWritingSystemsAreNotCollapsed() throws {
        let simplified = Locale.Language(identifier: "zh-Hans")
        let traditional = Locale.Language(identifier: "zh-Hant")

        #expect(!simplified.isEquivalent(to: traditional))
        #expect(simplified.maximalIdentifier != traditional.maximalIdentifier)

        let result = TranslationTargetOrdering.ordered(
            supported: [simplified, traditional],
            preferred: [],
            displayLocale: Self.english
        )

        // The falsifying half of the pair above: a de-duplication that also collapsed
        // this would regress the carve-out that lets a reader who needs Traditional
        // Chinese ask for it, and the two rows do read differently.
        #expect(result.count == 2)
        #expect(Set(result) == Set([simplified, traditional]))
        #expect(
            simplified.localizedTargetName(in: Self.english)
                != traditional.localizedTargetName(in: Self.english)
        )
    }

    @Test("An empty supported set orders to an empty list — the control is absent, never disabled")
    func emptyInEmptyOut() throws {
        let result = TranslationTargetOrdering.ordered(
            supported: [],
            preferred: [Locale(identifier: "en_GB")],
            displayLocale: Self.english
        )

        #expect(result.isEmpty)
    }
}
