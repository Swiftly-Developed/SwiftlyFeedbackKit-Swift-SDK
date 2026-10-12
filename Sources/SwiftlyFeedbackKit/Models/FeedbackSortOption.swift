import Foundation

/// Sort options for the feedback list
public enum FeedbackSortOption: String, CaseIterable, Sendable {
    case votes = "Votes"
    case newest = "Newest"
    case oldest = "Oldest"
    case comments = "Comments"

    var localizedName: String {
        switch self {
        case .votes: return Strings.sortVotes
        case .newest: return Strings.sortNewest
        case .oldest: return Strings.sortOldest
        case .comments: return Strings.sortComments
        }
    }
}
