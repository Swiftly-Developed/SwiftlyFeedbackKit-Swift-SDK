import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// `QA-UNIT05-FEEDBACK` `-07`, status half — **the SDK's `FeedbackStatus` declares no glyph
/// channel at all** (finding **F4**), and this file is where that gap is recorded.
///
/// §4.4's corollary is the reason this is here rather than in `QA-UI03-FEEDBACK`: a channel
/// that is *missing from the map* is this suite's red. `QA-UI03` literally cannot assert a
/// glyph on the SDK's `StatusBadge` — there is no value for the view to render — so it would
/// have to record "not applicable" and the gap would disappear from both matrices.
///
/// The presentation triple is **complete in exactly one client**. The Admin's `FeedbackStatus`
/// has `icon` + `color` + `localizedDisplayName` but no `canVote`; the SDK's has `canVote` +
/// `localizedDisplayName` + a tint (on `Theme`, not on the enum) but no glyph. Each client is
/// missing a different channel of the same three-channel contract.
///
/// **These assertions are written against what ships, and they go red when the gap is
/// closed.** That is deliberate: §20 carries the remediation, and a red on the day someone
/// adds `FeedbackStatus.icon` to the SDK is exactly the signal that says "three cases now
/// move into `-07`'s status half".
@Suite struct FeedbackStatusPresentationGapTests {

    // MARK: - -07 · the absent status glyph

    /// `-07` / **F4** — the SDK's `FeedbackStatus` declares no `icon` / `iconName` /
    /// `systemImage` member, while its sibling `FeedbackCategory` in the same file does.
    ///
    /// The paired positive is what stops this being a green built from an absence: asserting
    /// only "the SDK has no status glyph" is also true of a file that declares no enums at
    /// all, or that this suite failed to open. `FeedbackCategory.iconName` is read from the
    /// same slice, so the scan is proven to be looking at the right thing.
    @Test("-07 · The SDK's FeedbackStatus declares no glyph while FeedbackCategory declares one")
    func theSDKStatusEnumHasNoGlyphChannelAndTheCategoryEnumDoes() throws {
        let source = try WorkspaceSourceTree.sdkSource(
            "Sources/SwiftlyFeedbackKit/Models/Feedback.swift"
        )

        let statusSlice = try #require(
            WorkspaceSourceTree.slice(
                source,
                from: "public enum FeedbackStatus: String",
                to: "public enum FeedbackCategory: String"
            ),
            "Could not isolate FeedbackStatus in the SDK's Feedback.swift — the anchors moved."
        )
        let categorySlice = source.components(separatedBy: "public enum FeedbackCategory: String")[1]

        for glyphMember in ["var icon:", "var iconName:", "var systemImage:", "var symbolName:"] {
            #expect(
                !statusSlice.contains(glyphMember),
                """
                F4 is closed: the SDK's FeedbackStatus now declares \(glyphMember). Delete \
                this case and author -07's status half as a six-case glyph table with a \
                pairwise-distinctness clause, mirroring FeedbackCategoryMappingTests.
                """
            )
        }

        // Paired positive — the scan is looking at the right file and the right slice.
        #expect(statusSlice.contains("public var canVote: Bool"))
        #expect(statusSlice.contains("public var localizedDisplayName: String"))
        #expect(categorySlice.contains("public var iconName: String"))
    }

    /// `-07` / **F4** — and the consequence, stated where a reader of the failure will see it:
    /// `StatusBadge` renders text and tint only.
    ///
    /// This is the assertion that makes §4.4's third sentence checkable. A colour-only badge
    /// passes every mapping case in this spine perfectly; what it cannot do is emit a glyph
    /// the map never declared.
    @Test("-07 · The SDK's StatusBadge renders no Image, because there is no glyph to render")
    func theSDKStatusBadgeRendersNoGlyph() throws {
        let source = try WorkspaceSourceTree.sdkSource(
            "Sources/SwiftlyFeedbackKit/Views/FeedbackRowView.swift"
        )
        let badge = try #require(
            WorkspaceSourceTree.slice(source, from: "struct StatusBadge", to: "struct CategoryBadge"),
            "Could not isolate StatusBadge in FeedbackRowView.swift — the anchors moved."
        )

        #expect(
            !badge.contains("Image(systemName:"),
            """
            The SDK's StatusBadge now renders an SF Symbol. If FeedbackStatus gained a glyph \
            channel, F4 is closed and -07's status half is owed a six-case table here plus an \
            accessibility assertion in QA-UI03-FEEDBACK.
            """
        )
        // Paired positive — the badge does render the two channels the map does declare.
        #expect(badge.contains("localizedDisplayName"))
        #expect(badge.contains("statusColors"))
    }

    // MARK: - F1 · the SDK's predicate shape

    /// **F1** — the SDK's `canVote` is the one compliant site: an exhaustive `switch` with
    /// **both arms listed explicitly** and no `default`.
    ///
    /// `AGENTS.md` requires an inclusion list, *"never by negating the terminal set … a
    /// negation silently starts matching (or blocking) every token a future phase adds"*. Five
    /// of the six shipped predicates negate; only this one does not, and on a seventh status
    /// it is the only one that **fails to compile** — the loudest and most correct outcome
    /// available.
    ///
    /// Behavioural cases cannot see this. `-09` and `-10` are green on a negation today and
    /// green on this switch today; the shapes only diverge on a change that has not happened
    /// yet. Pinning the shape is what keeps the compliant site compliant through a
    /// "simplification".
    @Test("-07 · The SDK's canVote is an exhaustive switch with both arms and no default")
    func theSDKCanVoteIsAnExhaustiveSwitchWithNoDefaultArm() throws {
        let source = try WorkspaceSourceTree.sdkSource(
            "Sources/SwiftlyFeedbackKit/Models/Feedback.swift"
        )
        let predicate = try #require(
            WorkspaceSourceTree.slice(
                source,
                from: "public var canVote: Bool",
                to: "public enum FeedbackCategory"
            ),
            "Could not isolate the SDK's canVote — the anchors moved."
        )

        #expect(predicate.contains("switch self"))
        #expect(predicate.contains("case .completed, .rejected:"))
        #expect(predicate.contains("case .pending, .approved, .inProgress, .testflight:"))
        #expect(
            !predicate.contains("default:"),
            """
            The SDK's canVote gained a `default:` arm. That converts the one AGENTS.md-compliant \
            can-vote site in the workspace into a sixth negation: a seventh status would stop \
            being a compile error and would silently become votable.
            """
        )
        #expect(
            !predicate.contains("self != "),
            "The SDK's canVote was rewritten as a negation of the terminal set (AGENTS.md forbids it)."
        )
    }
}
