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
}
