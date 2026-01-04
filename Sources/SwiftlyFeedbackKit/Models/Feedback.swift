import Foundation

public struct Feedback: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let title: String
    public let description: String
    public let status: FeedbackStatus
    public let category: FeedbackCategory
    public let userId: String
    public let userEmail: String?
    public let voteCount: Int
    public let hasVoted: Bool
    public let commentCount: Int
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(
        id: UUID,
        title: String,
        description: String,
        status: FeedbackStatus,
        category: FeedbackCategory,
        userId: String,
        userEmail: String?,
        voteCount: Int,
        hasVoted: Bool,
        commentCount: Int,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.category = category
        self.userId = userId
        self.userEmail = userEmail
        self.voteCount = voteCount
        self.hasVoted = hasVoted
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum FeedbackStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case approved
    case inProgress = "in_progress"
    case completed
    case rejected

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .rejected: return "Rejected"
        }
    }

    public var canVote: Bool {
        switch self {
        case .completed, .rejected:
            return false
        case .pending, .approved, .inProgress:
            return true
        }
    }
}

public enum FeedbackCategory: String, Codable, Sendable, CaseIterable {
    case featureRequest = "feature_request"
    case bugReport = "bug_report"
    case improvement
    case other

    public var displayName: String {
        switch self {
        case .featureRequest: return "Feature Request"
        case .bugReport: return "Bug Report"
        case .improvement: return "Improvement"
        case .other: return "Other"
        }
    }

    public var iconName: String {
        switch self {
        case .featureRequest: return "lightbulb"
        case .bugReport: return "ladybug"
        case .improvement: return "arrow.up.circle"
        case .other: return "ellipsis.circle"
        }
    }
}
