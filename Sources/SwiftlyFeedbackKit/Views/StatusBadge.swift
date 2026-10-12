import SwiftUI

struct StatusBadge: View {
    let status: FeedbackStatus

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    private var statusColor: Color {
        theme.statusColors.color(for: status).resolve(for: colorScheme)
    }

    var body: some View {
        Text(status.localizedDisplayName)
            .font(.body)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            // The status name is the differentiator. The wash stays as a tint, and the
            // text uses the primary label color so caption contrast is not the status hue.
            .foregroundStyle(.primary)
            .clipShape(.capsule)
    }
}
