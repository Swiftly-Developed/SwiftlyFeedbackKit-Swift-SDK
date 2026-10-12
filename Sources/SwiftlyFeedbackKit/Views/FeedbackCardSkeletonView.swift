import SwiftUI

/// One ghost row of the list's loading skeleton.
///
/// Renders the **real** `FeedbackCardView` — the same struct the loaded state
/// renders — fed placeholder values whose rendered metrics match a typical row,
/// under `redacted(reason: .placeholder)`. Because ghost and content share one
/// struct and one layout, the transition to real data shifts nothing
/// (UI-DESIGN-IOS.md → "Loading, Empty, Error": no layout shift).
struct FeedbackCardSkeletonView: View {
    /// Placeholder feedback with plausible metrics: a fixed-width ~28-character
    /// title, a description long enough to wrap onto a second line, and
    /// realistic counts. Never rendered legibly — always redacted.
    private static let placeholder = Feedback(
        id: UUID(),
        title: "Placeholder feedback headline",
        description: "Placeholder description text that is long enough to wrap onto a second line at typical widths.",
        status: .pending,
        category: .featureRequest,
        userId: "placeholder",
        userEmail: nil,
        voteCount: 12,
        hasVoted: false,
        commentCount: 3,
        createdAt: nil,
        updatedAt: nil
    )

    var body: some View {
        FeedbackCardView(feedback: Self.placeholder, onVote: {})
            .redacted(reason: .placeholder)
            .disabled(true)
    }
}

#Preview {
    FeedbackCardSkeletonView()
        .padding()
}
