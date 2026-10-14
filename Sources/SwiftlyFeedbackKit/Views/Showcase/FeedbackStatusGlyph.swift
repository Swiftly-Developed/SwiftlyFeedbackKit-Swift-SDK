import SwiftUI

/// A small progress ring that encodes the status by shape as well as colour: dashed for
/// Pending, empty for Approved, a half and three-quarter pie for In Progress and TestFlight,
/// and a filled mark for Completed and Rejected.
///
/// Decorative: the status name always sits beside it.
struct FeedbackStatusGlyph: View {
    let status: FeedbackStatus
    let color: Color
    let size: CGFloat

    var body: some View {
        let shape = FeedbackStatusGlyphShape(status: status)
        let line = max(1.5, size * 0.12)
        let pie = size - line * 4

        ZStack {
            switch shape {
            case .dashedRing:
                Circle()
                    .strokeBorder(color, style: StrokeStyle(lineWidth: line, dash: [size * 0.17, size * 0.13]))
            case .ring:
                Circle()
                    .strokeBorder(color, lineWidth: line)
            case .halfRing, .threeQuarterRing:
                Circle()
                    .strokeBorder(color, lineWidth: line)
                Circle()
                    .trim(from: 0, to: shape.progress ?? 0)
                    .stroke(color, style: StrokeStyle(lineWidth: pie / 2))
                    .frame(width: pie / 2, height: pie / 2)
                    .rotationEffect(.degrees(-90))
            case .check, .cross:
                Circle()
                    .fill(color)
                Image(systemName: shape == .check ? "checkmark" : "xmark")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.black)
                    .foregroundStyle(Color.white)
                    .frame(width: size * 0.46, height: size * 0.46)
            }
        }
        .frame(width: size, height: size)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(FeedbackStatus.allCases, id: \.self) { status in
            FeedbackStatusGlyph(status: status, color: Color.accentColor, size: 18)
        }
    }
    .padding()
}
