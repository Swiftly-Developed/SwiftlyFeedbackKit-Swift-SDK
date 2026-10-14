import SwiftUI

/// The Showcase list chrome per platform: inset-grouped cards with tightened spacing on iOS,
/// the inset list on macOS (which has no inset-grouped style), the grouped list on visionOS,
/// and the hard top scroll edge where the platform offers it.
struct FeedbackShowcaseListStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .listStyle(.insetGrouped)
            .listSectionSpacing(FeedbackShowcaseMetrics.sectionSpacing)
            .scrollEdgeEffectStyle(.hard, for: .top)
        #elseif os(macOS)
        content
            .listStyle(.inset)
            .scrollEdgeEffectStyle(.hard, for: .top)
        #elseif os(visionOS)
        content
            .listStyle(.grouped)
        #endif
    }
}
