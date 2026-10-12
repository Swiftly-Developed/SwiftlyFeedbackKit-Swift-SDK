import Foundation
import SwiftUI
import Testing
@testable import SwiftlyFeedbackKit

/// `QA-UNIT05-FEEDBACK` `-06`, SDK half — declaration site 1 of 9 of the `status → tint` map:
/// `Theme.swift`'s `StatusColors`, the only publicly-overridable copy.
///
/// **`QA-UI03-FEEDBACK` §1 states outright that tint is never asserted at L3** — FeedbackKit
/// has no AI-vision judge and no pixel adjudication. So the tint has exactly one possible
/// owner in the whole matrix, and it is this suite. If these cases do not assert the colour,
/// a tint regression has *no failure signal anywhere*.
///
/// The canon all nine declarations must match is the root `CLAUDE.md` *Feedback Statuses*
/// table: gray / blue / orange / cyan / green / red. The other eight sites are the Admin
/// target's `FeedbackTintDeclarationDriftTests` (`-08`), which is where seven of them live.
@Suite struct FeedbackStatusTintMapTests {

    static let expectedStatusTints: [(status: FeedbackStatus, tint: ThemeColor)] = [
        (.pending, .color(.gray)),
        (.approved, .color(.blue)),
        (.inProgress, .color(.orange)),
        (.testflight, .color(.cyan)),
        (.completed, .color(.green)),
        (.rejected, .color(.red)),
    ]

    static let expectedCategoryTints: [(category: FeedbackCategory, tint: ThemeColor)] = [
        (.featureRequest, .color(.purple)),
        (.bugReport, .color(.red)),
        (.improvement, .color(.teal)),
        (.other, .color(.gray)),
    ]

    // MARK: - -06 · the six defaults

    /// `-06` — each status's **default** tint is the specific colour the product law names.
    ///
    /// A fresh `StatusColors()` rather than `SwiftlyFeedback.theme.statusColors`: the shared
    /// theme is a process-global that another case in this target mutates via
    /// `SwiftlyFeedback.configure`, and a default-value assertion read off a mutated global is
    /// a coin flip.
    @Test("-06 · Every FeedbackStatus's default tint is the one CLAUDE.md declares",
          arguments: FeedbackStatusTintMapTests.expectedStatusTints)
    func defaultStatusTintPerCase(_ row: (status: FeedbackStatus, tint: ThemeColor)) {
        #expect(StatusColors().color(for: row.status) == row.tint)
    }

    /// `-06` — the six defaults are **pairwise distinct**.
    ///
    /// A map that is entirely gray satisfies every "returns a colour" check ever written, and
    /// renders six statuses as one badge. This is the clause that sees it.
    @Test("-06 · The six default status tints are pairwise distinct")
    func theSixDefaultTintsArePairwiseDistinct() {
        let colors = StatusColors()
        let tints = FeedbackStatus.allCases.map { colors.color(for: $0) }
        #expect(Set(tints).count == FeedbackStatus.allCases.count)
    }

    /// `-06` — `color(for:)` genuinely reads the **overridable** property rather than a
    /// second, hardcoded `switch`.
    ///
    /// `StatusColors` is public API whose whole purpose is that a host app can retint the
    /// badge. A resolver that ignored its own stored properties would pass every assertion
    /// above and silently discard every host override — and the failure would only ever be
    /// visible on someone else's screen. Each case is overridden separately so a resolver
    /// wired to the wrong property is caught too.
    @Test("-06 · color(for:) resolves through the overridable stored property, per case")
    func colorForResolvesThroughTheOverridableProperty() {
        let colors = StatusColors()

        colors.pending = .color(.purple)
        colors.approved = .color(.brown)
        colors.inProgress = .color(.pink)
        colors.testflight = .color(.indigo)
        colors.completed = .color(.mint)
        colors.rejected = .color(.yellow)

        #expect(colors.color(for: .pending) == .color(.purple))
        #expect(colors.color(for: .approved) == .color(.brown))
        #expect(colors.color(for: .inProgress) == .color(.pink))
        #expect(colors.color(for: .testflight) == .color(.indigo))
        #expect(colors.color(for: .completed) == .color(.mint))
        #expect(colors.color(for: .rejected) == .color(.yellow))
    }

    /// `-06` — the category tint map, likewise. It is a separate arity and a separate canon.
    @Test("-06 · Every FeedbackCategory's default tint is its declared colour",
          arguments: FeedbackStatusTintMapTests.expectedCategoryTints)
    func defaultCategoryTintPerCase(_ row: (category: FeedbackCategory, tint: ThemeColor)) {
        #expect(CategoryColors().color(for: row.category) == row.tint)
    }

    /// `-06` — the category tints are **not** pairwise distinct today, and that is recorded
    /// rather than asserted away.
    ///
    /// `bugReport` is `.red` and `other` is `.gray`, which no status shares; but the four are
    /// four distinct colours among themselves. Stating the count explicitly means a future
    /// collapse — two categories tinted alike — is a red here rather than something noticed
    /// in a screenshot.
    @Test("-06 · The four default category tints are pairwise distinct")
    func theFourCategoryTintsArePairwiseDistinct() {
        let colors = CategoryColors()
        let tints = FeedbackCategory.allCases.map { colors.color(for: $0) }
        #expect(Set(tints).count == FeedbackCategory.allCases.count)
    }
}
