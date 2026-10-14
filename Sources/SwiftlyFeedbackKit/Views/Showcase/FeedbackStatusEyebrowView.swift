import SwiftUI

/// The status line at the top of a Showcase card: the status glyph and name in the host's
/// status colour, as given. The glyph scales with Dynamic Type and sits on the text's
/// cap-height centre.
struct FeedbackStatusEyebrowView: View {
    let status: FeedbackStatus

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var glyphSize = 12
    /// Half the footnote cap height, so the glyph's centre lands on the text's optical middle.
    @ScaledMetric(relativeTo: .footnote) private var capCenter = 4.5

    var body: some View {
        let statusColor = SwiftlyFeedback.appearance.statusColors.color(for: status).resolve(for: colorScheme)
        let capCenter = capCenter
        Label {
            Text(status.localizedDisplayName)
                .foregroundStyle(statusColor)
        } icon: {
            FeedbackStatusGlyph(status: status, color: statusColor, size: glyphSize)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + capCenter }
        }
        .labelStyle(FeedbackShowcaseBaselineLabelStyle())
        .font(.footnote.weight(.semibold))
    }
}
