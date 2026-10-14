import SwiftUI

/// Category and comment count, as small labels in a Showcase card's footer.
///
/// Side by side when they fit on one line; otherwise stacked, and then free to wrap, so
/// nothing truncates at any size.
struct FeedbackShowcaseFooterFacts: View {
    /// `nil` when `showCategoryBadge` is off.
    let category: FeedbackCategory?
    /// `nil` when `showCommentSection` is off or there are no comments.
    let commentCount: Int?

    @ScaledMetric(relativeTo: .footnote) private var horizontalSpacing = 14
    @ScaledMetric(relativeTo: .footnote) private var verticalSpacing = 4

    var body: some View {
        let facts = Group {
            if let category {
                Label {
                    Text(category.localizedDisplayName)
                } icon: {
                    Image(systemName: category.iconName)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: .accessibilityCategory(category.localizedDisplayName)))
            }
            if let commentCount {
                Label {
                    Text(commentCount, format: .number)
                } icon: {
                    Image(systemName: "bubble.left")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: .accessibilityCommentCount(commentCount)))
            }
        }

        FeedbackShowcaseRowOrStackLayout(
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
            rowAlignment: .firstTextBaseline
        ) {
            facts
        }
        .labelStyle(FeedbackShowcaseBaselineLabelStyle())
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}
