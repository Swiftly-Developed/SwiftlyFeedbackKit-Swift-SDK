import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `QA-UNIT05-FEEDBACK` — `-02`, `-03`, `-04`, `-05` and the **category half of `-07`** on the
/// Swift SDK's `FeedbackCategory`.
///
/// Separated from `FeedbackStatusMappingTests` because the two enums have different arities.
/// A four-case regression must not be able to hide behind a six-case suite's green — a
/// combined file that loops `allCases` over "the enums" would do exactly that.
///
/// `FeedbackCategory` is also the SDK's **only** enum with a glyph channel. `FeedbackStatus`
/// has none (finding **F4**), which is why `-07` is a separate ID and why its status half
/// lives in `FeedbackStatusPresentationGapTests` as an assertion about an absence.
@Suite struct FeedbackCategoryMappingTests {

    /// The canon, once: case · wire spelling · English name · SF Symbol.
    static let expected: [(category: FeedbackCategory, raw: String, english: String, glyph: String)] = [
        (.featureRequest, "feature_request", "Feature Request", "lightbulb"),
        (.bugReport, "bug_report", "Bug Report", "ladybug"),
        (.improvement, "improvement", "Improvement", "arrow.up.circle"),
        (.other, "other", "Other", "ellipsis.circle"),
    ]

    // MARK: - -02 · the English display-name map

    @Test("-02 · Every FeedbackCategory returns its specific English display name",
          arguments: FeedbackCategoryMappingTests.expected)
    func englishDisplayNamePerCase(
        _ row: (category: FeedbackCategory, raw: String, english: String, glyph: String)
    ) {
        #expect(row.category.displayName == row.english)
    }

    /// `-02` — cardinality and pairwise distinctness, the two things a per-case table cannot
    /// catch on its own. Four correct pairs stay green when a fifth category appears, and
    /// stay green when two arms return the same string.
    @Test("-02 · FeedbackCategory has exactly four distinct English display names")
    func theFourEnglishNamesAreDistinctAndComplete() {
        #expect(FeedbackCategory.allCases.count == 4)
        #expect(
            Set(FeedbackCategory.allCases) == [.featureRequest, .bugReport, .improvement, .other]
        )

        let names = FeedbackCategory.allCases.map(\.displayName)
        #expect(Set(names).count == 4)
        #expect(names.allSatisfy { !$0.isEmpty })
    }

    // MARK: - -07 · the category glyph channel

    /// `-07` — each category returns **its own** SF Symbol.
    ///
    /// What this catches is two categories sharing a symbol, which renders as two
    /// indistinguishable rows and which no test at any other layer would see: `QA-UI03` can
    /// assert *a* glyph reached the accessibility tree, not that it was the *right* one.
    @Test("-07 · Every FeedbackCategory returns its specific SF Symbol",
          arguments: FeedbackCategoryMappingTests.expected)
    func glyphPerCase(
        _ row: (category: FeedbackCategory, raw: String, english: String, glyph: String)
    ) {
        #expect(row.category.iconName == row.glyph)
    }

    /// `-07` — the four glyphs are pairwise distinct and none is empty.
    @Test("-07 · The four category glyphs are pairwise distinct")
    func theFourGlyphsArePairwiseDistinct() {
        let glyphs = FeedbackCategory.allCases.map(\.iconName)
        #expect(Set(glyphs).count == 4)
        #expect(glyphs.allSatisfy { !$0.isEmpty })
    }

    // MARK: - -04 · the wire enum

    @Test("-04 · Every FeedbackCategory raw value round-trips through its wire spelling",
          arguments: FeedbackCategoryMappingTests.expected)
    func rawValuePerCase(
        _ row: (category: FeedbackCategory, raw: String, english: String, glyph: String)
    ) {
        #expect(row.category.rawValue == row.raw)
        #expect(FeedbackCategory(rawValue: row.raw) == row.category)
    }

    @Test("-04 · The four category raw values are pairwise distinct")
    func rawValuesArePairwiseDistinct() {
        #expect(
            Set(FeedbackCategory.allCases.map(\.rawValue)).count == FeedbackCategory.allCases.count
        )
    }

    // MARK: - -05 · the unknown-token disposition

    /// `-05` — an unknown category token throws, and a known one decodes. The negative and
    /// its paired positive, because a negative oracle alone is satisfied by a decoder that
    /// throws on everything.
    @Test("-05 · An unknown category token throws while a known one decodes")
    func theCategoryDecoderThrowsOnUnknownAndSucceedsOnKnown() throws {
        struct Holder: Decodable { let category: FeedbackCategory }

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Holder.self, from: Data(#"{"category":"quantum"}"#.utf8))
        }

        let decoded = try JSONDecoder().decode(
            Holder.self, from: Data(#"{"category":"feature_request"}"#.utf8)
        )
        #expect(decoded.category == .featureRequest)
    }

    @Test("-05 · Near-miss category tokens construct nothing")
    func nearMissCategoryTokensConstructNothing() {
        #expect(FeedbackCategory(rawValue: "featureRequest") == nil)
        #expect(FeedbackCategory(rawValue: "feature-request") == nil)
        #expect(FeedbackCategory(rawValue: "Bug Report") == nil)
        #expect(FeedbackCategory(rawValue: "") == nil)
    }

    // MARK: - -03 · the localized display-name map

    /// `-03` — four distinct, non-empty localized values.
    ///
    /// ⚠️ Same toolchain caveat as the status half: `swift build` never compiles a String
    /// Catalog, so under `swift test` `String(localized:)` falls back to the key. The
    /// "resolves to a real translation, not the key" claim is the **Admin** lane's, where
    /// `xcodebuild` compiles the catalog. Distinctness holds either way — under a fallback
    /// the values *are* the keys, so a collision is still a collision.
    @Test("-03 · The four localized category names are distinct and non-empty")
    func localizedCategoryNamesAreDistinct() {
        let localized = FeedbackCategory.allCases.map(\.localizedDisplayName)
        #expect(Set(localized).count == 4)
        #expect(localized.allSatisfy { !$0.isEmpty })
    }

    /// `-03` — and each arm points at the key holding **its own** English value, read from
    /// the catalog rather than through `String(localized:)` so the assertion does not depend
    /// on the process's ambient locale. See `StringCatalogReader` for why.
    @Test("-03 · Each category's lookup key holds that category's English name in the catalog")
    func eachCategoryKeyHoldsItsOwnEnglishValueInTheCatalog() throws {
        let keys = [
            "category.featureRequest", "category.bugReport",
            "category.improvement", "category.other",
        ]

        for (index, row) in Self.expected.enumerated() {
            let catalogValue = try StringCatalogReader.englishValue(for: keys[index])
            #expect(
                catalogValue == row.english,
                """
                The SDK catalog's en value for \(keys[index]) is "\(catalogValue)" but \
                FeedbackCategory.\(row.raw)'s English map says "\(row.english)".
                """
            )
        }
        #expect(Set(keys).count == 4)
        #expect(Set(try keys.map { try StringCatalogReader.englishValue(for: $0) }).count == 4)
    }
}
