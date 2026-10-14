import SwiftUI

/// The body of `FeedbackShowcaseCapsuleButtonStyle`, a view so padding scales and the
/// enabled state is read from the environment.
///
/// The hit area grows past the drawn capsule to 44 by 44 points without taking layout
/// space, so the card's footer is not padded out at small sizes.
struct FeedbackShowcaseCapsuleButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let emphasis: FeedbackShowcaseCapsuleButtonStyle.Emphasis
    let tint: Color

    @SwiftUI.Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .subheadline) private var horizontalPadding = FeedbackShowcaseMetrics.capsuleHorizontalPadding
    @ScaledMetric(relativeTo: .subheadline) private var verticalPadding = 7
    @State private var capsuleSize = CGSize.zero

    private var hitExpansion: CGFloat {
        let shortestSide = min(capsuleSize.width, capsuleSize.height)
        return max(0, (FeedbackShowcaseMetrics.minimumHitSize - shortestSide) / 2)
    }

    var body: some View {
        label
            .foregroundStyle(foreground)
            .opacity(emphasis == .placeholder ? 0 : 1)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(background, in: .capsule)
            .opacity(isPressed ? 0.6 : 1)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { capsuleSize = $0 }
            .contentShape(.interaction, .rect.inset(by: -hitExpansion))
            // The accessibility frame stays on the drawn capsule; with the margin included the
            // contrast audit samples the card around the capsule instead of the count on it.
            .contentShape(.accessibility, .capsule)
            #if os(visionOS)
            .contentShape(.hoverEffect, .capsule)
            .hoverEffect(.highlight)
            #endif
    }

    private var foreground: AnyShapeStyle {
        switch emphasis {
        case .prominent:
            AnyShapeStyle(Color.white)
        case .bordered, .placeholder:
            isEnabled ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary)
        }
    }

    private var background: AnyShapeStyle {
        switch emphasis {
        // A voted capsule keeps its full fill even when undo is off: it states that the reader
        // voted.
        case .prominent:
            AnyShapeStyle(tint)
        case .bordered, .placeholder:
            AnyShapeStyle(.fill.tertiary)
        }
    }
}
