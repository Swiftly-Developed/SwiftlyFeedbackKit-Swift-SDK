import SwiftUI

struct CategoryBadge: View {
    let category: FeedbackCategory

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    private var categoryColor: Color {
        theme.categoryColors.color(for: category).resolve(for: colorScheme)
    }

    var body: some View {
        Text(category.localizedDisplayName)
            .font(.body)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor.opacity(0.15))
            .foregroundStyle(.primary)
            .clipShape(.capsule)
    }
}
