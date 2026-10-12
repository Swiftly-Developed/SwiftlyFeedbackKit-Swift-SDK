import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `QA-UNIT05-FEEDBACK` `-11` — **cross-client agreement of the can-vote partition**, plus the
/// structural record of finding **F1**.
///
/// A per-client `-09` can be green in all of them while the clients *disagree*: each lane's
/// runner can only ever see its own language. Six declarations of one rule live in six
/// modules, in four languages, in five separate build products, and nothing in the workspace
/// links them. That is `AGENTS.md`'s definition of a compile-green silent-inertness seam:
/// *"Two types that must agree on a stored string literal is a contract."*
///
/// **Why source text and not a call.** Three of the six predicates cannot be linked from any
/// Swift test process — Kotlin, Dart, TypeScript — and the fourth lives in a *separate* SPM
/// package (`SwiftlyFeedbackKit-Vapor`) that has no test target at all
/// (`QA-UNIT12-VAPOR-SDK`, reserved). The alternative to reading the declarations is not a
/// better test; it is no test, and six copies of a product rule with no link between them.
///
/// **F1, measured and recorded, not specced around.** Exactly one of the six uses an inclusion
/// list. Five negate the terminal set, which `AGENTS.md` forbids by name because *"a negation
/// silently starts matching (or blocking) every token a future phase adds"*. On a seventh
/// status the Swift SDK **fails to compile**; Vapor, Kotlin, Flutter, RN and the server all
/// silently treat it as **votable** — the permissive direction, on a status the server may
/// well intend to be terminal. The remediation is §20's, not this suite's.
@Suite struct FeedbackCanVoteParityTests {

    /// The canon: the two statuses on which voting is refused. Root `CLAUDE.md` states this
    /// partition as product law.
    static let terminalTokens: Set<String> = ["completed", "rejected"]

    /// Every status token, in the normalized spelling `normalize(_:)` produces. Used to prove
    /// a scan found *only* the terminal two rather than, say, all six.
    static let allTokens: Set<String> = [
        "pending", "approved", "inprogress", "testflight", "completed", "rejected",
    ]

    /// One declaration site of the can-vote rule.
    struct PredicateSite: Sendable {
        let client: String
        let path: String
        /// The line the predicate's declaration starts on.
        let startAnchor: String
        /// The first line *after* the predicate. The slice is exclusive of it.
        let endAnchor: String
        /// `false` for the one site that uses an inclusion list — its slice names all six
        /// cases by design, so its terminal set is derived from the `false`-returning arm
        /// instead (`theSwiftSDKPredicateIsAnInclusionList`).
        let isNegation: Bool
    }

    /// The six sites, measured on this tree. Paths are workspace-relative.
    static let sites: [PredicateSite] = [
        PredicateSite(
            client: "Swift SDK",
            path: "SwiftlyFeedbackKit/Sources/SwiftlyFeedbackKit/Models/Feedback.swift",
            startAnchor: "public var canVote: Bool",
            endAnchor: "public enum FeedbackCategory",
            isNegation: false
        ),
        PredicateSite(
            client: "Vapor SDK",
            path: "SwiftlyFeedbackKit-Vapor/Sources/SwiftlyFeedbackKitVapor/Models/Feedback.swift",
            startAnchor: "public var canVote: Bool",
            endAnchor: "public enum FeedbackCategory",
            isNegation: true
        ),
        PredicateSite(
            client: "Kotlin SDK",
            path: "SwiftlyFeedbackKit-Kotlin/feedbackkit/src/main/kotlin/com/swiftlydeveloped/feedbackkit/models/FeedbackStatus.kt",
            startAnchor: "val canVote: Boolean",
            endAnchor: "String resource ID",
            isNegation: true
        ),
        PredicateSite(
            client: "Flutter SDK",
            path: "SwiftlyFeedbackKit-Flutter/lib/src/models/feedback_status.dart",
            startAnchor: "bool get canVote",
            endAnchor: "}",
            isNegation: true
        ),
        PredicateSite(
            client: "React Native SDK",
            path: "SwiftlyFeedbackKit-RN/src/components/VoteButton.tsx",
            startAnchor: "const canVote =",
            endAnchor: "const handlePress",
            isNegation: true
        ),
        PredicateSite(
            client: "Server (inline guard)",
            path: "SwiftlyFeedbackServer/Sources/App/Controllers/VoteController.swift",
            startAnchor: "// Check if feedback status allows voting",
            endAnchor: "let dto = try req.content.decode(CreateVoteDTO.self)",
            isNegation: true
        ),
    ]

    /// Strip comments, then fold every language's spelling of a status onto one token.
    ///
    /// Comments go first and it matters: `Kotlin`'s predicate carries a doc comment reading
    /// *"Voting is blocked for completed and rejected feedback"*, and a scan that read it
    /// would find the right answer from the **prose** on a predicate that had been rewritten
    /// to say something else entirely.
    static func normalize(_ text: String) -> String {
        let uncommented = text
            .components(separatedBy: .newlines)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("*") || trimmed.hasPrefix("/*") {
                    return ""
                }
                if let range = line.range(of: "//") { return String(line[line.startIndex..<range.lowerBound]) }
                return line
            }
            .joined(separator: "\n")

        return uncommented
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    static func tokens(in text: String) -> Set<String> {
        let normalized = normalize(text)
        return Set(allTokens.filter { normalized.contains($0) })
    }

    static func predicateSlice(for site: PredicateSite) throws -> String {
        let source = try WorkspaceSourceTree.source(site.path)
        let slice = WorkspaceSourceTree.slice(source, from: site.startAnchor, to: site.endAnchor)
        return try #require(
            slice,
            """
            Could not isolate \(site.client)'s can-vote predicate in \(site.path) between \
            "\(site.startAnchor)" and "\(site.endAnchor)". The declaration moved, and a \
            cross-client gate that cannot find a declaration must fail rather than pass.
            """
        )
    }

    // MARK: - -11 · the partition, per declaration site

    /// `-11` — every **negating** declaration names exactly `{completed, rejected}` and
    /// nothing else.
    ///
    /// A negation's whole expression *is* its terminal set, so the token scan is the
    /// partition. Add `testflight` to any one of the five and this reddens naming the client;
    /// drop `rejected` from any one and it reddens too. Neither is visible to that client's
    /// own `-09`, which would be equally green on either side of the disagreement.
    @Test("-11 · Every negating can-vote declaration names exactly {completed, rejected}",
          arguments: FeedbackCanVoteParityTests.sites.filter(\.isNegation))
    func everyNegatingSiteNamesExactlyTheTerminalPair(_ site: PredicateSite) throws {
        try WorkspaceSourceTree.requireWorkspace()
        let slice = try Self.predicateSlice(for: site)

        #expect(
            Self.tokens(in: slice) == Self.terminalTokens,
            """
            \(site.client)'s can-vote rule in \(site.path) names \
            \(Self.tokens(in: slice).sorted()) — the canon is \
            \(Self.terminalTokens.sorted()). Six copies of this rule ship in five build \
            products and nothing but this gate links them.
            """
        )
    }

    /// `-11` — the one **inclusion-list** site, derived from its `false`-returning arm.
    ///
    /// The Swift SDK's slice names all six cases by design, so a whole-slice token scan would
    /// return all six and prove nothing. Its `false` arm is the terminal set, and the `true`
    /// arm is the complement — asserting **both** is what makes this the same claim the five
    /// negations make, rather than a weaker one.
    @Test("-11 · The Swift SDK's inclusion list partitions into the same two sets")
    func theSwiftSDKInclusionListPartitionsIdentically() throws {
        try WorkspaceSourceTree.requireWorkspace()
        let site = try #require(Self.sites.first { $0.client == "Swift SDK" })
        let slice = try Self.predicateSlice(for: site)

        let falseArm = try #require(
            WorkspaceSourceTree.slice(slice, from: "case .completed, .rejected:", to: "case .pending"),
            "The Swift SDK's false-returning arm is no longer spelled `case .completed, .rejected:`."
        )
        let trueArm = try #require(
            WorkspaceSourceTree.slice(slice, from: "case .pending", to: "}"),
            "The Swift SDK's true-returning arm moved."
        )

        #expect(falseArm.contains("return false"))
        #expect(trueArm.contains("return true"))
        #expect(Self.tokens(in: falseArm) == Self.terminalTokens)
        #expect(Self.tokens(in: trueArm) == Self.allTokens.subtracting(Self.terminalTokens))
    }

    /// `-11`, the runtime anchor — the one predicate this process **can call** partitions the
    /// way the five source-derived ones say they do.
    ///
    /// Without this, `-11` is six source reads agreeing with each other and with nothing
    /// executable. This is the case that ties the derivation to a value.
    @Test("-11 · The linkable predicate's computed partition matches the derived canon")
    func theLinkablePredicateAgreesWithTheDerivedCanon() {
        let blocked = Set(FeedbackStatus.allCases.filter { !$0.canVote }.map { Self.normalize($0.rawValue) })
        let votable = Set(FeedbackStatus.allCases.filter(\.canVote).map { Self.normalize($0.rawValue) })

        #expect(blocked == Self.terminalTokens)
        #expect(votable == Self.allTokens.subtracting(Self.terminalTokens))
    }

    // MARK: - F1 · the shapes, recorded

    /// **F1** — five of the six sites negate, and exactly one uses an inclusion list.
    ///
    /// The count itself is the finding. Asserting it means the day someone converts a
    /// negation to a `when` / `switch` (the §20 remediation) this file goes red and gets
    /// updated deliberately, rather than the census quietly going stale — which is how a
    /// documented finding becomes fiction.
    @Test("-11 · Exactly one of the six can-vote declarations is an inclusion list")
    func exactlyOneDeclarationUsesAnInclusionList() throws {
        try WorkspaceSourceTree.requireWorkspace()

        #expect(Self.sites.count == 6)
        #expect(Self.sites.filter { !$0.isNegation }.count == 1)
        #expect(Self.sites.filter(\.isNegation).count == 5)

        for site in Self.sites where site.isNegation {
            let slice = Self.normalize(try Self.predicateSlice(for: site))
            let negates = slice.contains("!=") || slice.contains("!==") || slice.contains("==")
            #expect(
                negates,
                """
                \(site.client) no longer expresses can-vote as a comparison against the \
                terminal set. If it became an exhaustive switch/when, F1 shrank by one — \
                flip its isNegation to false and give it an inclusion-list assertion.
                """
            )
        }
    }

    /// **F1** — the two clients that declare *no* predicate at all still declare none.
    ///
    /// The Admin app and the JS SDK are the absences in the census. Recording them means the
    /// day one gains a `canVote` this suite says so, and `-09`/`-11` gain a client. Without
    /// it, "absent" is a claim in a document that nothing checks.
    @Test("-11 · The Admin app and the JS SDK still declare no can-vote predicate")
    func theTwoClientsWithNoPredicateStillHaveNone() throws {
        try WorkspaceSourceTree.requireWorkspace()

        let adminModels = try WorkspaceSourceTree.source(
            "SwiftlyFeedbackAdmin/SwiftlyFeedbackAdmin/Models/FeedbackModels.swift"
        )
        let jsTypes = try WorkspaceSourceTree.source("SwiftlyFeedbackKit-JS/src/models/types.ts")

        #expect(
            !adminModels.contains("canVote"),
            """
            The Admin app's FeedbackModels.swift now mentions canVote. If FeedbackStatus \
            gained the predicate, the Admin becomes a fifth client for -09/-11 and this \
            census entry is stale.
            """
        )
        #expect(
            !jsTypes.contains("canVote"),
            "The JS SDK's types.ts now mentions canVote — the RN component's inline copy may now be extractable."
        )

        // Paired positives — both files really are the ones the census names.
        #expect(adminModels.contains("enum FeedbackStatus: String"))
        #expect(jsTypes.contains("export enum FeedbackStatus"))
    }
}
