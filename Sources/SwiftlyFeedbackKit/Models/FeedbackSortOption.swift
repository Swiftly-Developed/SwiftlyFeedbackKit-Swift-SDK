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
}
