import SwiftUI

/// The body of `FeedbackShowcaseBaselineLabelStyle`, a view so the gap can scale.
struct FeedbackShowcaseBaselineLabel<Icon: View, Title: View>: View {
    let icon: Icon
    let title: Title

    @ScaledMetric(relativeTo: .footnote) private var spacing = 5

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            icon
            title
        }
    }
}
