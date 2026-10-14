import SwiftUI

/// How the vote control is drawn.
///
/// The count never sits on a solid label fill. An unvoted control is a tinted
/// border, a voted control is a light wash of that same tint, and a placeholder
/// skeleton is a gray block with no stroke. A solid stroke under redaction
/// becomes a filled black rectangle.
struct VoteButtonChrome: Equatable {
    var fill: Fill
    var showsStroke: Bool
    /// Always false. Present so a test can fail if a solid label fill returns.
    var usesSolidLabelFill: Bool

    enum Fill: Equatable {
        case clear
        case tintWash
        case placeholder
    }

    static func resolve(isPlaceholder: Bool, hasVoted: Bool) -> VoteButtonChrome {
        if isPlaceholder {
            return VoteButtonChrome(fill: .placeholder, showsStroke: false, usesSolidLabelFill: false)
        }
        if hasVoted {
            return VoteButtonChrome(fill: .tintWash, showsStroke: true, usesSolidLabelFill: false)
        }
        return VoteButtonChrome(fill: .clear, showsStroke: true, usesSolidLabelFill: false)
    }
}
