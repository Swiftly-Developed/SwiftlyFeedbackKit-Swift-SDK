import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `TRANSLATION01` phase 03 — the reader's persisted translation target.
///
/// Every case takes its own scratch `UserDefaults` domain via ``ScratchDefaults``. No case
/// constructs the store with the process defaults: `UserDefaults.standard` in a test is
/// process-global shared state, and a case that reads a sibling's write or the developer's
/// real domain passes while proving nothing.
///
/// Every assertion names its own `Locale` and none reads the host's — a dev machine is a
/// fixture, and a case that takes the process locale passes vacuously on the machine it
/// was written on.
///
/// ⚠️ **The language sets below are stand-ins, not Apple's.** The contents of
/// `LanguageAvailability.supportedLanguages` are unverified until the device walk, and no
/// assertion here depends on them. `roundTripsForEveryStandInLanguage` asserts a property
/// that holds *given* distinct `maximalIdentifier`s — which the case checks rather than
/// assumes — and `duplicateBearingSetResolvesToTheFirstMember` asserts what happens when
/// that assumption fails. Neither claims which one Apple ships.
@Suite struct TranslationTargetStoreTests {

    /// Distinct `maximalIdentifier` for all 25, checked in the sweep rather than assumed.
    private static let standInLanguages: [Locale.Language] = [
        "ar", "de", "en-GB", "en-US", "es", "es-419", "fr", "fr-CA", "hi", "id", "it",
        "ja", "ko", "nl", "pl", "pt-BR", "pt-PT", "ru", "th", "tr", "uk", "vi",
        "zh-Hans", "zh-Hant", "zh-HK"
    ].map { Locale.Language(identifier: $0) }

    @Test("An install that has never chosen reads nil — today's behaviour is unchanged")
    func neverChosenReadsNil() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        // The key is absent, so the read returns before the membership guard and emits no
        // log line at all — the only branch that logs is the withdrawn one below.
        #expect(scratch.rawValue(forKey: TranslationTargetStore.defaultsKey) == nil)
        #expect(store.storedTarget(in: Self.standInLanguages) == nil)
    }

    @Test("An identifier naming no real language reads nil, empty and whitespace alike")
    func unparseableIdentifierReadsNil() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        // `languageCode` cannot separate "unparseable" from "withdrawn" — Foundation
        // accepts any well-formed subtag — so this case and the withdrawn one below
        // exercise a single branch from two directions.
        for junk in ["zzz-not-a-language", "", "   ", "!!!"] {
            scratch.defaults.set(junk, forKey: TranslationTargetStore.defaultsKey)
            #expect(
                store.storedTarget(in: Self.standInLanguages) == nil,
                "Stored identifier \"\(junk)\" resolved to something"
            )
        }

        // Positive control: the same store, same domain, reads a real value.
        scratch.defaults.set("de", forKey: TranslationTargetStore.defaultsKey)
        #expect(store.storedTarget(in: Self.standInLanguages) == Locale.Language(identifier: "de"))
    }

    @Test("A stored language the device no longer offers reads nil; one it does offer reads the member")
    func withdrawnLanguageReadsNil() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        let korean = Locale.Language(identifier: "ko")
        store.setTarget(korean)

        let without = Self.standInLanguages.filter { !$0.isEquivalent(to: korean) }
        #expect(without.count == Self.standInLanguages.count - 1)
        #expect(store.storedTarget(in: without) == nil)
        #expect(store.storedTarget(in: Self.standInLanguages) == korean)
    }

    @Test("Resolve falls back to the environment locale's language, and prefers a usable stored choice")
    func resolveFallsBackToTheEnvironmentLocale() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        // Named explicitly; the host's locale is never read.
        let german = Locale(identifier: "de_DE")

        let fallback = store.resolvedTarget(locale: german, supported: Self.standInLanguages)
        // The fallback IS `locale.language`, which carries the region and is therefore
        // NOT `==` to a bare `de` — the same component-wise equality the read operation
        // exists to respect.
        #expect(fallback == german.language)
        #expect(fallback.languageCode?.identifier == "de")

        let japanese = Locale.Language(identifier: "ja")
        store.setTarget(japanese)
        #expect(store.resolvedTarget(locale: german, supported: Self.standInLanguages) == japanese)
    }

    @Test("Persisting nil removes the key from the domain rather than writing an empty value")
    func persistingNilClearsTheKey() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        store.setTarget(Locale.Language(identifier: "de"))
        #expect(scratch.rawValue(forKey: TranslationTargetStore.defaultsKey) as? String == "de")

        store.setTarget(nil)
        // Asserted on the domain, not on the store's own read, so an implementation whose
        // read and write are wrong in the same direction cannot satisfy it by agreeing
        // with itself.
        #expect(scratch.rawValue(forKey: TranslationTargetStore.defaultsKey) == nil)
        #expect(store.storedTarget(in: Self.standInLanguages) == nil)
    }

    @Test("Every stand-in language survives a persist-and-read as the picker's own tag")
    func roundTripsForEveryStandInLanguage() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        // The premise of the property, checked rather than assumed: the guarantee holds
        // only for a set whose members have distinct maximal identifiers.
        #expect(Set(Self.standInLanguages.map(\.maximalIdentifier)).count == Self.standInLanguages.count)

        for language in Self.standInLanguages {
            store.setTarget(language)
            let read = store.storedTarget(in: Self.standInLanguages)
            // `==`, not `isEquivalent`: the returned value must be the very member a
            // picker tags its rows with, or the control comes back from a relaunch with
            // no selection at all.
            #expect(read == language, "Round-trip lost \(language.minimalIdentifier)")
        }
    }

    @Test("A language carrying no code clears the key instead of writing an empty identifier")
    func codelessLanguagePersistsAsNothing() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        store.setTarget(Locale.Language(identifier: "fr"))
        #expect(scratch.rawValue(forKey: TranslationTargetStore.defaultsKey) as? String == "fr")

        let codeless = Locale.Language(components: Locale.Language.Components())
        #expect(codeless.languageCode == nil)
        store.setTarget(codeless)
        #expect(scratch.rawValue(forKey: TranslationTargetStore.defaultsKey) == nil)
    }

    @Test("""
    A supported set holding two equivalent members resolves to the FIRST, and the \
    ordering collapses the pair so the reader is never offered the choice it cannot keep
    """)
    func duplicateBearingSetResolvesToTheFirstMember() throws {
        let scratch = try ScratchDefaults()
        defer { scratch.tearDown() }
        let store = TranslationTargetStore(defaults: scratch.defaults)

        // `en` and `en-US` share BOTH identifier accessors — minimal `en`, maximal
        // `en-Latn-US` — and differ only in `region`, which no BCP-47 string carries. No
        // choice of persisted representation separates them, so the store's own answer
        // below is unchanged and unchangeable.
        //
        // What DID change: the pre-designed repair — de-duplication in the ordering — has
        // since been applied, so leg (d) records the collapse rather than the two
        // indistinguishable rows it used to pin. Legs (a)-(c) are the reason the repair
        // exists and are untouched.
        let plain = Locale.Language(identifier: "en")
        let american = Locale.Language(identifier: "en-US")
        let supported = [plain, american, Locale.Language(identifier: "de")]
        #expect(plain != american)
        #expect(plain.minimalIdentifier == american.minimalIdentifier)
        #expect(plain.maximalIdentifier == american.maximalIdentifier)

        store.setTarget(american)
        let read = try #require(store.storedTarget(in: supported))

        // (a) the first member wins
        #expect(read == plain)
        // (b) and is therefore not the value that was chosen
        #expect(read != american)
        // (c) but it is equivalent, so translation still goes to the right language and
        //     only the picker's checkmark is wrong
        #expect(read.isEquivalent(to: american))

        // (d) so the picker never offers the pair as two rows: the ordering collapses
        //     them to the one member the search above returns, and the checkmark lands
        //     on the row the reader actually picked.
        let displayLocale = Locale(identifier: "en_US")
        let rows = TranslationTargetOrdering.ordered(
            supported: supported,
            preferred: [],
            displayLocale: displayLocale
        )
        let englishRows = rows.filter { $0.isEquivalent(to: american) }
        #expect(englishRows == [plain])
        #expect(rows.count == 2)
    }
}
