import Foundation
import Testing
@testable import SwiftlyFeedbackKit

@Suite
struct LanguageFlagTests {

    @Test func englishUsesTheUnitedStatesFlag() {
        #expect(LanguageFlag.emoji(for: Locale.Language(identifier: "en")) == "🇺🇸")
    }

    @Test func dutchUsesTheNetherlandsFlag() {
        #expect(LanguageFlag.emoji(for: Locale.Language(identifier: "nl")) == "🇳🇱")
    }

    @Test func brazilianPortugueseUsesBrazil() {
        #expect(LanguageFlag.emoji(for: Locale.Language(identifier: "pt-BR")) == "🇧🇷")
    }

    @Test func traditionalChineseUsesTaiwan() {
        #expect(LanguageFlag.emoji(for: Locale.Language(identifier: "zh-Hant")) == "🇹🇼")
    }

    @Test func anUnknownLanguageHasNoFlag() {
        #expect(LanguageFlag.emoji(for: Locale.Language(identifier: "und")) == nil)
    }

    @Test func labeledNameKeepsTheFlagInFront() {
        #expect(LanguageFlag.labeled("Dutch", language: Locale.Language(identifier: "nl")) == "🇳🇱 Dutch")
    }

    @Test func aTwoLetterRegionBecomesItsFlag() {
        #expect(LanguageFlag.flag(forRegionCode: "fr") == "🇫🇷")
        #expect(LanguageFlag.flag(forRegionCode: "FRA") == nil)
    }
}
