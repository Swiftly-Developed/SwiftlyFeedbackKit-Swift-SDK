import SwiftUI

/// Icon and title on one first-text baseline with a tight, scaled gap, for the card's
/// eyebrow and footer facts.
struct FeedbackShowcaseBaselineLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        FeedbackShowcaseBaselineLabel(icon: configuration.icon, title: configuration.title)
    }
}
