import SwiftUI

/// Empty state for the detail screen's comments card, shown once a comments
/// fetch has completed with zero results.
///
/// No action button: UI-DESIGN-IOS's Empty guidance wants an action, and the
/// add-comment composer sits directly beneath this view in the same card —
/// the adjacent composer *is* the action.
struct CommentsEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label(String(localized: .feedbackDetailCommentsEmpty), systemImage: "bubble.right")
        } description: {
            Text(String(localized: .feedbackDetailCommentsEmptyDescription))
        }
    }
}

#Preview {
    CommentsEmptyStateView()
        .padding()
}
