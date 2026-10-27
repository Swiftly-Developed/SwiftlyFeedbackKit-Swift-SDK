import SwiftUI

/// A Showcase card's footer: facts on the leading side, the vote control on the trailing side.
///
/// When the two do not fit side by side the footer stacks them, facts first, both leading,
/// so a long category name or a four-digit count never pushes the capsule off the card.
struct FeedbackShowcaseFooter: View {
    let feedbackID: UUID
    let category: FeedbackCategory?
    let commentCount: Int?
    let voteCount: Int
    let presentation: VotePresentation
    let tint: Color
    let onVote: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var spacing = 12

    private var hasFacts: Bool { category != nil || commentCount != nil }

    var body: some View {
        let capsule = FeedbackShowcaseVoteCapsule(
            feedbackID: feedbackID,
            voteCount: voteCount,
            presentation: presentation,
            tint: tint,
            action: onVote
        )
        let facts = FeedbackShowcaseFooterFacts(category: category, commentCount: commentCount)

        FeedbackShowcaseRowOrStackLayout(
            horizontalSpacing: spacing,
            verticalSpacing: spacing,
            // With no capsule the facts are the last child; pinning would push them trailing.
            pinsLastToTrailingEdge: presentation != .hidden
        ) {
            if hasFacts { facts }
            capsule
        }
    }
}
