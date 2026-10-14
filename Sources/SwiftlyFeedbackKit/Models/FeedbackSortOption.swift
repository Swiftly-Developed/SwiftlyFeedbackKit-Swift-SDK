import Foundation

/// Sort options for the feedback list
public enum FeedbackSortOption: String, CaseIterable, Sendable {
    case votes = "Votes"
    case newest = "Newest"
    case oldest = "Oldest"
    case comments = "Comments"

    var localizedName: String {
        switch self {
        case .votes: return String(localized: .sortVotes)
        case .newest: return String(localized: .sortNewest)
        case .oldest: return String(localized: .sortOldest)
        case .comments: return String(localized: .sortComments)
        }
    }

    /// The glyph beside each option in the Sort & Filter menu.
    var systemImage: String {
        switch self {
        case .votes: return "arrow.up"
        case .newest: return "sparkles"
        case .oldest: return "clock"
        case .comments: return "bubble.left.and.bubble.right"
        }
    }
}
