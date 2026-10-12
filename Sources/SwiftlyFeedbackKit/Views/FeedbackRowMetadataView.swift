import SwiftUI

struct FeedbackRowMetadataView: View {
    let feedback: Feedback

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }

    var body: some View {
        HStack {
            if config.showStatusBadge {
                StatusBadge(status: feedback.status)
            }

            if config.showCategoryBadge {
                CategoryBadge(category: feedback.category)
            }

            Spacer()

            if feedback.commentCount > 0 && config.showCommentSection {
                Label {
                    Text(feedback.commentCount, format: .number)
                } icon: {
                    Image(systemName: "bubble.right")
                }
                .font(.body)
                .foregroundStyle(.primary)
                .accessibilityLabel(String(localized: .accessibilityCommentCount(feedback.commentCount)))
            }
        }
    }
}
