import SwiftUI

struct FeedbackEmptyStateView: View {
    let onSubmit: () -> Void
    let onSubmitDisabled: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: .feedbackListEmpty), systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text(String(localized: .feedbackListEmptyDescription))
        } actions: {
            Button(String(localized: .feedbackSubmitTitle)) {
                if config.allowFeedbackSubmission {
                    onSubmit()
                } else {
                    onSubmitDisabled()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primaryColor.resolve(for: colorScheme))
        }
    }
}
