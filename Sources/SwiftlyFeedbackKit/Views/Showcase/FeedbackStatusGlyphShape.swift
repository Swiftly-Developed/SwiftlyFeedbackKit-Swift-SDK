import Foundation

/// The shape that encodes a status in the Showcase eyebrow, so colour is never the only channel.
///
/// Internal on purpose: the public `FeedbackStatus` carries no glyph (see
/// `FeedbackStatusPresentationGapTests`).
enum FeedbackStatusGlyphShape: Equatable, Hashable, Sendable {
    case dashedRing
    case ring
    case halfRing
    case threeQuarterRing
    case check
    case cross

    init(status: FeedbackStatus) {
        switch status {
        case .pending: self = .dashedRing
        case .approved: self = .ring
        case .inProgress: self = .halfRing
        case .testflight: self = .threeQuarterRing
        case .completed: self = .check
        case .rejected: self = .cross
        }
    }

    /// The closest SF Symbol, for menus, where custom drawing is not available.
    var menuSymbolName: String {
        switch self {
        case .dashedRing: "circle.dashed"
        case .ring: "circle"
        case .halfRing: "circle.lefthalf.filled"
        case .threeQuarterRing: "chart.pie.fill"
        case .check: "checkmark.circle.fill"
        case .cross: "xmark.circle.fill"
        }
    }

    var isFilledMark: Bool {
        switch self {
        case .check, .cross: true
        case .dashedRing, .ring, .halfRing, .threeQuarterRing: false
        }
    }

    /// How much of the inner pie is filled, for the progress rings.
    var progress: Double? {
        switch self {
        case .halfRing: 0.5
        case .threeQuarterRing: 0.75
        case .dashedRing, .ring, .check, .cross: nil
        }
    }
}
