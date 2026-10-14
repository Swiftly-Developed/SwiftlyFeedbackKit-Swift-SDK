import SwiftUI

/// The Showcase loading skeleton: the real `FeedbackShowcaseCard` fed placeholder values and
/// redacted, one section per ghost, so ghost and content share one layout and nothing shifts
/// on arrival.
///
/// The region reads as one VoiceOver element naming what is loading.
struct FeedbackShowcaseSkeletonView: View {
    private static let placeholders: [Feedback] = (0..<4).map { index in
        Feedback(
            id: UUID(),
            title: "Placeholder feedback headline",
            description: "Placeholder description text that is long enough to wrap onto a second line at typical widths.",
            status: .pending,
            category: .featureRequest,
            userId: "placeholder",
            userEmail: nil,
            voteCount: 120 - index * 20,
            hasVoted: false,
            commentCount: 3,
            createdAt: nil,
            updatedAt: nil
        )
    }

    var body: some View {
        List {
            ForEach(Self.placeholders) { feedback in
                Section {
                    FeedbackShowcaseCard(feedback: feedback, onVote: {})
                }
            }
        }
        .modifier(FeedbackShowcaseListStyleModifier())
        .redacted(reason: .placeholder)
        .disabled(true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: .accessibilityLoadingFeedback))
    }
}

#Preview {
    FeedbackShowcaseSkeletonView()
}
