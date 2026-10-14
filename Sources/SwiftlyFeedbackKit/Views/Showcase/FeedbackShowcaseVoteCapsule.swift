import SwiftUI

/// The vote control at the trailing end of a Showcase card's footer.
///
/// Votable requests get a capsule button; completed and rejected requests get the count as
/// plain text, because a disabled button reads as a fault rather than a fact.
struct FeedbackShowcaseVoteCapsule: View {
    let feedbackID: UUID
    let voteCount: Int
    let presentation: VotePresentation
    let tint: Color
    let action: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var closedTrailingPadding = FeedbackShowcaseMetrics.capsuleHorizontalPadding

    var body: some View {
        // The arrow is not mirrored in right-to-left layouts: it means "up", not "forward".
        let countLabel = Label {
            Text(voteCount, format: .number)
                .monospacedDigit()
        } icon: {
            Image(systemName: "arrow.up")
                .imageScale(.small)
        }
        .labelStyle(FeedbackShowcaseBaselineLabelStyle())
        .font(.subheadline.weight(.semibold))
        .fixedSize()

        switch presentation {
        case .hidden:
            EmptyView()
        case .closed:
            countLabel
                .foregroundStyle(.secondary)
                .padding(.trailing, closedTrailingPadding)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: .accessibilityVoteCount(voteCount)))
                .accessibilityValue(presentation.accessibilityValue?.localizedText ?? "")
                .accessibilityIdentifier("fbk-feedback-vote-count-\(feedbackID.uuidString)")
        case .placeholder:
            Button(action: {}) { countLabel }
                .buttonStyle(FeedbackShowcaseCapsuleButtonStyle(emphasis: .placeholder, tint: tint))
                .disabled(true)
                .accessibilityHidden(true)
        case .vote, .unvote, .votedLocked:
            Button(action: action) { countLabel }
                .buttonStyle(FeedbackShowcaseCapsuleButtonStyle(
                    emphasis: presentation.isProminent ? .prominent : .bordered,
                    tint: tint
                ))
                .disabled(!presentation.isEnabled)
                .accessibilityLabel(String(localized: .accessibilityVoteCount(voteCount)))
                .accessibilityValue(presentation.accessibilityValue?.localizedText ?? "")
                .accessibilityHint(presentation.accessibilityHint?.localizedText ?? "")
                .accessibilityInputLabels([
                    String(localized: presentation.isProminent ? .buttonVoted : .buttonVote),
                    voteCount.formatted(.number),
                ])
                .accessibilityIdentifier("fbk-feedback-vote-button-\(feedbackID.uuidString)")
        }
    }
}
