import SwiftUI

/// The Showcase vote capsule: the tint on a system fill before voting, a solid tint fill
/// after, the bare system fill as a placeholder.
///
/// A style of our own rather than `.bordered` so the hit area can be held at 44 by 44 points
/// at every Dynamic Type size while the visible capsule stays text-sized.
struct FeedbackShowcaseCapsuleButtonStyle: ButtonStyle {
    enum Emphasis {
        case bordered
        case prominent
        case placeholder
    }

    let emphasis: Emphasis
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        FeedbackShowcaseCapsuleButtonBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            emphasis: emphasis,
            tint: tint
        )
    }
}
