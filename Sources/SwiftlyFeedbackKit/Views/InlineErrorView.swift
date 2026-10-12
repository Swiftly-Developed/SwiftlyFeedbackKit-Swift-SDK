import SwiftUI

/// Inline failure state for the feedback list's initial content load.
///
/// Renders the `.failed` arm with the already-localized message and a Retry
/// action. Refresh failures with rows on screen never reach this view — they
/// keep `.loaded` and surface through the existing alert path instead.
struct InlineErrorView: View {
    let message: String
    let onRetry: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    var body: some View {
        ContentUnavailableView {
            Label(Strings.errorLoadFailedTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(Strings.errorRetryButton) {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primaryColor.resolve(for: colorScheme))
        }
    }
}

#Preview {
    InlineErrorView(message: "The request timed out.") {}
}
