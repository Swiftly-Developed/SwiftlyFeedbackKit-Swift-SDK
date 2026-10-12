import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `QA-UNIT05-FEEDBACK` — `-01`, `-03`, `-04`, `-05`, `-09` and `-10` on the **Swift SDK**'s
/// `FeedbackStatus`.
///
/// Every case here asserts a **specific value per case**, never `allCases` + non-nil. That
/// loop is the trap this whole suite is shaped around: it is green against a `displayName`
/// that returns `"Pending"` six times, green against a glyph map that returns `clock` six
/// times, and green *the day a seventh status is added* — which is precisely the change this
/// domain most recently took. It has the shape of thoroughness and carries no information.
///
/// The per-case table is paired with two things it cannot do on its own: **cardinality**
/// (`allCases.count == 6`) and **pairwise distinctness**. A table of six correct pairs stays
/// green when a seventh case appears, and stays green when two arms return the same string.
///
/// Authored inside a named `@Suite` type per `QA-UNIT01-FOUNDATION` C3 — the type name is the
/// `--filter` token. The five file-scope `@Test func`s already in this target are the shape
/// C3 exists to stop, and are not extended.
@Suite struct FeedbackStatusMappingTests {

    /// The canon, once. Root `CLAUDE.md`'s *Feedback Statuses* table is the product law for
    /// the six cases; this is that table transcribed, and every assertion below reads it.
    static let expected: [(status: FeedbackStatus, raw: String, english: String, canVote: Bool)] = [
        (.pending, "pending", "Pending", true),
        (.approved, "approved", "Approved", true),
        (.inProgress, "in_progress", "In Progress", true),
        (.testflight, "testflight", "TestFlight", true),
        (.completed, "completed", "Completed", false),
        (.rejected, "rejected", "Rejected", false),
    ]

    // MARK: - -01 · the English display-name map

    /// `-01` — each of the six statuses returns **its own** English literal.
    @Test("-01 · Every FeedbackStatus returns its specific English display name",
          arguments: FeedbackStatusMappingTests.expected)
    func englishDisplayNamePerCase(_ row: (status: FeedbackStatus, raw: String, english: String, canVote: Bool)) {
        #expect(row.status.displayName == row.english)
    }

    /// `-01` — the six English names are **pairwise distinct**.
    ///
    /// This is the copy-paste oracle: a `switch` arm duplicated without editing its return —
    /// `.testflight` returning `"Completed"` — satisfies every per-case check that happens to
    /// have been written against the *other* arm, and satisfies every non-empty check
    /// outright. Only distinctness sees it.
    @Test("-01 · The six English display names are pairwise distinct and non-empty")
    func englishDisplayNamesArePairwiseDistinct() {
        let names = FeedbackStatus.allCases.map(\.displayName)
        #expect(Set(names).count == FeedbackStatus.allCases.count)
        #expect(names.allSatisfy { !$0.isEmpty })
    }

    // MARK: - -10 · the 7th-status tripwire

    /// `-10` — `allCases` is exactly the six statuses, and there are exactly six.
    ///
    /// The single highest-value case in the suite, and it only works at L1 because it needs
    /// `allCases` — a reflection over the *type*, not over any data. A per-case table cannot
    /// detect an **addition**; only this arithmetic can.
    @Test("-10 · FeedbackStatus.allCases is exactly the six declared statuses")
    func allCasesIsExactlyTheSixStatuses() {
        #expect(FeedbackStatus.allCases.count == 6)
        #expect(
            Set(FeedbackStatus.allCases)
                == [.pending, .approved, .inProgress, .testflight, .completed, .rejected]
        )
    }

    /// `-10` — the can-vote false-set, **computed**, is exactly `{completed, rejected}`.
    ///
    /// This is the assertion that survives every one of the six shipped predicate shapes
    /// (finding **F1**): an inclusion list, a negation, and an exhaustive `switch` all
    /// produce the same computed set today, and all three produce a *different* one the day
    /// a seventh status arrives. `-09`'s table of six pairs stays green then, because a
    /// seventh case is simply not in the table.
    @Test("-10 · The computed can-vote false-set is exactly {completed, rejected}")
    func theCanVoteFalseSetIsExactlyTheTwoTerminalStatuses() {
        let blocked = Set(FeedbackStatus.allCases.filter { !$0.canVote })
        let votable = Set(FeedbackStatus.allCases.filter(\.canVote))

        #expect(blocked == [.completed, .rejected])
        #expect(votable == [.pending, .approved, .inProgress, .testflight])
        #expect(blocked.count == 2)
        #expect(blocked.count + votable.count == FeedbackStatus.allCases.count)
    }

    // MARK: - -09 · the can-vote truth table

    /// `-09` — the partition asserted **once per status, individually**.
    ///
    /// Six separate expectations rather than a spot check of the two terminal cases: an
    /// `||`/`&&` slip in a negating predicate flips *four* statuses at once while `completed`
    /// and `rejected` stay correct, so a two-case check passes on a predicate that has
    /// stopped working entirely.
    @Test("-09 · Every FeedbackStatus's canVote matches the product law",
          arguments: FeedbackStatusMappingTests.expected)
    func canVotePerCase(_ row: (status: FeedbackStatus, raw: String, english: String, canVote: Bool)) {
        #expect(row.status.canVote == row.canVote)
    }

    // MARK: - -04 · the wire enum

    /// `-04` — each status's raw value is its exact snake_case wire spelling.
    ///
    /// A raw-value drift is the most expensive silent defect in the domain: it is a wire
    /// break in eight client declarations at once, and it is invisible to every display-name
    /// and predicate test, because the domain value is still constructed correctly in-process.
    @Test("-04 · Every FeedbackStatus raw value is its exact wire spelling",
          arguments: FeedbackStatusMappingTests.expected)
    func rawValuePerCase(_ row: (status: FeedbackStatus, raw: String, english: String, canVote: Bool)) {
        #expect(row.status.rawValue == row.raw)
        #expect(FeedbackStatus(rawValue: row.raw) == row.status)
    }

    /// `-04` — the six raw values are pairwise distinct.
    ///
    /// Derived from `allCases` rather than from the table, so it also covers a seventh case
    /// that copy-pastes an existing raw value — which makes `init(rawValue:)` unreachable for
    /// one of them with no compiler complaint.
    @Test("-04 · The six raw values are pairwise distinct")
    func rawValuesArePairwiseDistinct() {
        #expect(
            Set(FeedbackStatus.allCases.map(\.rawValue)).count == FeedbackStatus.allCases.count
        )
    }

    // MARK: - -05 · the unknown-token disposition

    /// `-05`, Swift half — an unknown status token makes the **decoder throw**.
    ///
    /// The disposition is asserted as the behaviour that actually ships, per client, because
    /// it is the *input* to `QA-UNIT10-SDK-PARITY`'s tolerance decision: a wrapper that
    /// catches `DecodingError.dataCorrupted` is useless against Flutter's `fromJson`, which
    /// never throws and returns `pending` instead. You cannot specify the wrapper's contract
    /// without first pinning the element's.
    @Test("-05 · An unknown status token throws DecodingError.dataCorrupted in Swift")
    func anUnknownStatusTokenThrows() {
        let payload = Data(#"{"status":"quantum"}"#.utf8)
        struct Holder: Decodable { let status: FeedbackStatus }

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Holder.self, from: payload)
        }
    }

    /// `-05` — paired positive: a **known** token decodes, so the negative above is not the
    /// suite's only signal and cannot be satisfied by a decoder that throws on everything.
    @Test("-05 · A known status token decodes to its case")
    func aKnownStatusTokenDecodes() throws {
        struct Holder: Decodable { let status: FeedbackStatus }
        let decoded = try JSONDecoder().decode(
            Holder.self, from: Data(#"{"status":"in_progress"}"#.utf8)
        )
        #expect(decoded.status == .inProgress)
    }

    /// `-05` — `init(rawValue:)` refuses the same tokens, including the near-misses that a
    /// premature `.lowercased()` or a camelCase drift would let through.
    @Test("-05 · Near-miss status tokens construct nothing")
    func nearMissStatusTokensConstructNothing() {
        #expect(FeedbackStatus(rawValue: "quantum") == nil)
        #expect(FeedbackStatus(rawValue: "inProgress") == nil)
        #expect(FeedbackStatus(rawValue: "in-progress") == nil)
        #expect(FeedbackStatus(rawValue: "TestFlight") == nil)
        #expect(FeedbackStatus(rawValue: "") == nil)
    }

    // MARK: - -03 · the localized display-name map

    /// The six catalog keys `localizedDisplayName` must resolve through, in `allCases` order.
    static let localizationKeys = [
        "status.pending", "status.approved", "status.inProgress",
        "status.testflight", "status.completed", "status.rejected",
    ]

    /// `-03` — the localized map returns a **distinct**, non-empty value per case.
    ///
    /// The claim is *the map has six different arms*, which is pure. Whether the German is
    /// idiomatic is `LOCALIZATION02`'s and whether it fits the badge is `QA-UI08`'s; neither
    /// can be answered here and neither needs to be, to catch a `String(localized: .statusTestflight)`
    /// arm pointing at `.completed`'s key. Two rendered strings would both be real, non-empty
    /// and plausible — only distinctness sees it.
    ///
    /// ⚠️ **This lane cannot assert that the value is a *translation*.** `swift build` never
    /// compiles a String Catalog, so under `swift test` the SDK's resource bundle carries a
    /// raw `Localizable.xcstrings` and `String(localized:)` falls back to returning the key.
    /// That is a property of the SPM toolchain, not of the product: `xcodebuild` compiles the
    /// catalog, which is why the "resolves to a real value, not the key" half of `-03` is
    /// authored in the **Admin** lane. Asserting it here would fail for a reason nobody can
    /// act on. Distinctness is unaffected — under a fallback the values *are* the keys, so a
    /// collision is still a collision.
    @Test("-03 · The six localized status names are distinct and non-empty")
    func localizedStatusNamesAreDistinct() {
        let localized = FeedbackStatus.allCases.map(\.localizedDisplayName)

        #expect(Set(localized).count == FeedbackStatus.allCases.count)
        #expect(localized.allSatisfy { !$0.isEmpty })
    }

    /// `-03` — each status's arm resolves through the key that **belongs to it**.
    ///
    /// Distinctness catches two arms sharing one key. It does **not** catch the whole map
    /// being shifted by one — six distinct keys, every one wrong, every rendered string real.
    ///
    /// This was a two-hop `case → Strings.member → catalog key` composition read out of the
    /// model plus the hand-written facade. Phase 03 deleted that facade: an arm now names the
    /// catalog key's **generated symbol** directly, so the composition collapsed to one hop
    /// and the middle file no longer exists. The symbol is a pure function of the key (split
    /// on `.`, capitalize each segment after the first, concatenate), so this derives the
    /// symbol each row *must* name and compares it to the one the arm actually names —
    /// exactly the shifted-by-one defect the two-hop version caught.
    ///
    /// Still read as source text rather than exercised: the runtime path is the one the
    /// uncompiled-catalog fallback described above disables under SwiftPM.
    @Test("-03 · Every status arm composes onto its own catalog key")
    func everyStatusArmComposesOntoItsOwnCatalogKey() throws {
        let model = try WorkspaceSourceTree.sdkSource("Sources/SwiftlyFeedbackKit/Models/Feedback.swift")

        let armSlice = try #require(
            WorkspaceSourceTree.slice(
                model, from: "public var localizedDisplayName: String", to: "public var canVote"
            ),
            "Could not isolate FeedbackStatus.localizedDisplayName — the anchors moved."
        )

        for (index, row) in Self.expected.enumerated() {
            let caseName = String(describing: FeedbackStatus.allCases[index])
            let armLine = try #require(
                armSlice.components(separatedBy: .newlines)
                    .first { $0.contains("case .\(caseName):") },
                "FeedbackStatus.localizedDisplayName has no arm for .\(caseName)."
            )

            // The symbol this row's key generates — derived, never hand-listed, so the
            // expectation cannot drift away from `localizationKeys` above.
            let key = Self.localizationKeys[index]
            let segments = key.components(separatedBy: ".")
            let expectedSymbol = segments.enumerated()
                .map { $0.offset == 0 ? $0.element : $0.element.prefix(1).uppercased() + $0.element.dropFirst() }
                .joined()

            #expect(
                armLine.contains("String(localized: .\(expectedSymbol))"),
                """
                FeedbackStatus.\(caseName)'s arm does not name .\(expectedSymbol), the symbol \
                generated from its own key \(key). A map shifted by one arm renders six real, \
                plausible, wrong strings and passes every distinctness and non-empty check ever \
                written. Arm as written: \(armLine.trimmingCharacters(in: .whitespaces)) \
                (row: \(row.english))
                """
            )
        }
    }

    /// `-03` — and each of those six keys holds **that status's** English name in the
    /// catalog itself.
    ///
    /// Read as data rather than through `String(localized:)`: the process locale is not
    /// pinned here, and `String(localized:locale:)` does not select the `.lproj` anyway, so a
    /// per-locale assertion written with it reads `en` and passes vacuously. This is an
    /// **en-catalog** assertion, never a translation one — whether a non-`en` value is
    /// idiomatic is `LOCALIZATION02`'s and `QA-UI08-PSEUDOLOCALIZATION`'s.
    @Test("-03 · Each status's lookup key holds that status's English name in the catalog")
    func eachStatusKeyHoldsItsOwnEnglishValueInTheCatalog() throws {
        for (index, row) in Self.expected.enumerated() {
            let key = Self.localizationKeys[index]
            let catalogValue = try StringCatalogReader.englishValue(for: key)
            #expect(
                catalogValue == row.english,
                """
                The SDK catalog's en value for \(key) is "\(catalogValue)" but \
                FeedbackStatus.\(row.raw)'s English map says "\(row.english)". Either the \
                catalog drifted or the localized switch arm points at the wrong key.
                """
            )
        }
        // Non-vacuity: the six keys really are six distinct catalog entries.
        #expect(Set(Self.localizationKeys).count == 6)
        #expect(
            Set(try Self.localizationKeys.map { try StringCatalogReader.englishValue(for: $0) })
                .count == 6
        )
    }
}
