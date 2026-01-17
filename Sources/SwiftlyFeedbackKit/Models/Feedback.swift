import Foundation
import SwiftUI

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
    // Merge-related fields
    public let mergedIntoId: UUID?
    public let mergedAt: Date?
    public let mergedFeedbackIds: [UUID]?
    // Rejection reason (only present when status is rejected)
    public let rejectionReason: String?

    /// Whether this feedback has been merged into another
    public var isMerged: Bool {
        mergedIntoId != nil
    }

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
        updatedAt: Date?,
        mergedIntoId: UUID? = nil,
        mergedAt: Date? = nil,
        mergedFeedbackIds: [UUID]? = nil,
        rejectionReason: String? = nil
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
        self.mergedIntoId = mergedIntoId
        self.mergedAt = mergedAt
        self.mergedFeedbackIds = mergedFeedbackIds
        self.rejectionReason = rejectionReason
    }
}

public enum FeedbackStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case approved
    case inProgress = "in_progress"
    case testflight
    case completed
    case rejected

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .inProgress: return "In Progress"
        case .testflight: return "TestFlight"
        case .completed: return "Completed"
        case .rejected: return "Rejected"
        }
    }

    /// Localized display name for the status
    public var localizedDisplayName: String {
        switch self {
        case .pending: return Strings.statusPending
        case .approved: return Strings.statusApproved
        case .inProgress: return Strings.statusInProgress
        case .testflight: return Strings.statusTestFlight
        case .completed: return Strings.statusCompleted
        case .rejected: return Strings.statusRejected
        }
    }

    public var canVote: Bool {
        switch self {
        case .completed, .rejected:
            return false
        case .pending, .approved, .inProgress, .testflight:
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

    /// Localized display name for the category
    public var localizedDisplayName: String {
        switch self {
        case .featureRequest: return Strings.categoryFeatureRequest
        case .bugReport: return Strings.categoryBugReport
        case .improvement: return Strings.categoryImprovement
        case .other: return Strings.categoryOther
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
