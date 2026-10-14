import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// UI01 phase 07 — the pure display-name helper behind the translation affordance's
/// "Translated from ⟨language⟩" label.
///
/// Every assertion uses **explicit** `Locale` instances, never `Locale.current` — a dev
/// machine is a fixture, and a test that reads the host locale passes vacuously on the
/// machine it was written on.
@Suite struct TranslationDisplayNameTests {

    @Test("German in an en_US display locale is the English exonym, never the raw code")
    func germanInEnglish() {
        let name = Locale.Language(identifier: "de").localizedDisplayName(in: Locale(identifier: "en_US"))
        #expect(name == "German")
    }

    @Test("A non-English display locale returns that locale's name for the language, not English")
    func germanInFrench() {
        let name = Locale.Language(identifier: "de").localizedDisplayName(in: Locale(identifier: "fr_FR"))
        // Non-vacuous: the name exists AND is the French exonym, not the English one.
        #expect(name != nil)
        #expect(name != "German")
        #expect(name == "allemand")
    }

    @Test("A language with no language code yields nil — the affordance is absent, never a raw code")
    func missingLanguageCodeYieldsNil() {
        let language = Locale.Language(components: Locale.Language.Components())
        #expect(language.languageCode == nil)
        #expect(language.localizedDisplayName(in: Locale(identifier: "en_US")) == nil)
    }

    @Test("The display locale, not the host locale, picks the name (endonym check)")
    func endonymInOwnLocale() {
        let name = Locale.Language(identifier: "de").localizedDisplayName(in: Locale(identifier: "de_DE"))
        #expect(name == "Deutsch")
    }

    // MARK: - localizedTargetName(in:) — TRANSLATION01 phase 03
    //
    // The picker's sibling of the helper above. It resolves the minimal identifier rather
    // than the bare language code, which is the whole reason it exists.

    @Test("Script and regional variants get distinct picker names where the older helper collapses them")
    func targetNameSeparatesVariantsTheSourceHelperCollapses() {
        let english = Locale(identifier: "en_US")
        let simplified = Locale.Language(identifier: "zh-Hans")
        let traditional = Locale.Language(identifier: "zh-Hant")

        #expect(simplified.localizedTargetName(in: english) == "Chinese")
        #expect(traditional.localizedTargetName(in: english) == "Chinese (Taiwan)")
        #expect(simplified.localizedTargetName(in: english) != traditional.localizedTargetName(in: english))

        // The falsification the whole helper rests on: the existing helper renders both
        // as one word, so a picker reusing it would show two identical rows for two
        // languages the pipeline now treats as genuinely different.
        #expect(simplified.localizedDisplayName(in: english) == traditional.localizedDisplayName(in: english))
    }

    @Test("The picker name is localized into the display locale, not left in English")
    func targetNameIsLocalizedIntoTheDisplayLocale() {
        let british = Locale.Language(identifier: "en-GB")
        let name = british.localizedTargetName(in: Locale(identifier: "de_DE"))
        #expect(name != nil)
        #expect(name != "English (United Kingdom)")
        #expect(name == "Englisch (Vereinigtes Königreich)")
    }

    @Test("A language with no name yields nil rather than echoing the identifier back")
    func targetNameIsNilForANamelessLanguage() {
        let english = Locale(identifier: "en_US")
        #expect(Locale.Language(identifier: "zzz").localizedTargetName(in: english) == nil)
        #expect(Locale.Language(identifier: "art-lojban").localizedTargetName(in: english) == nil)
        // Positive control, so a helper that returned nil for everything cannot pass.
        #expect(Locale.Language(identifier: "de").localizedTargetName(in: english) == "German")
    }

    @Test("The empty identifier is stopped by the language-code guard")
    func targetNameIsNilForTheEmptyIdentifier() {
        let empty = Locale.Language(identifier: "")
        #expect(empty.languageCode == nil)
        #expect(empty.localizedTargetName(in: Locale(identifier: "en_US")) == nil)
    }
}
