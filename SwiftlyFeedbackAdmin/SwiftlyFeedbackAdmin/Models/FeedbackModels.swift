import Foundation

// MARK: - Feedback Models
//
// All models are marked `nonisolated` to opt out of the project's default MainActor isolation.
// This allows their Codable conformances to be used from any actor context (e.g., AdminAPIClient).

// MARK: - Feedback

nonisolated
struct Feedback: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let title: String
    let description: String
    let status: FeedbackStatus
    let category: FeedbackCategory
    let userId: String
    let userEmail: String?
    let voteCount: Int
    let hasVoted: Bool
    let commentCount: Int
    /// Total MRR from the feedback creator plus all voters
    let totalMrr: Double?
    let createdAt: Date?
    let updatedAt: Date?
    // Merge-related fields
    let mergedIntoId: UUID?
    let mergedAt: Date?
    let mergedFeedbackIds: [UUID]?
    // GitHub integration fields
    let githubIssueUrl: String?
    let githubIssueNumber: Int?
    // ClickUp integration fields
    let clickupTaskUrl: String?
    let clickupTaskId: String?
    // Notion integration fields
    let notionPageUrl: String?
    let notionPageId: String?
    // Monday.com integration fields
    let mondayItemUrl: String?
    let mondayItemId: String?
    // Linear integration fields
    let linearIssueUrl: String?
    let linearIssueId: String?
    // Trello integration fields
    let trelloCardUrl: String?
    let trelloCardId: String?

    /// Formatted total MRR string for display (always shows, even if $0)
    var formattedMrr: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalMrr ?? 0)) ?? "$0"
    }

    /// Whether this feedback has been merged into another
    var isMerged: Bool {
        mergedIntoId != nil
    }

    /// Whether this feedback has received merges from other feedback
    var hasMergedFeedback: Bool {
        mergedFeedbackIds?.isEmpty == false
    }

    /// Number of feedbacks merged into this one
    var mergedCount: Int {
        mergedFeedbackIds?.count ?? 0
    }

    /// Whether this feedback has a linked GitHub issue
    var hasGitHubIssue: Bool {
        githubIssueUrl != nil
    }

    /// Whether this feedback has a linked ClickUp task
    var hasClickUpTask: Bool {
        clickupTaskUrl != nil
    }

    /// Whether this feedback has a linked Notion page
    var hasNotionPage: Bool {
        notionPageUrl != nil
    }

    /// Whether this feedback has a linked Monday.com item
    var hasMondayItem: Bool {
        mondayItemUrl != nil
    }

    /// Whether this feedback has a linked Linear issue
    var hasLinearIssue: Bool {
        linearIssueUrl != nil
    }

    /// Whether this feedback has a linked Trello card
    var hasTrelloCard: Bool {
        trelloCardUrl != nil
    }
}

// MARK: - Comment

nonisolated
struct Comment: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let content: String
    let userId: String
    let isAdmin: Bool
    let createdAt: Date?
}

// MARK: - Enums

nonisolated
enum FeedbackStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case pending
    case approved
    case inProgress = "in_progress"
    case testflight
    case completed
    case rejected

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .inProgress: return "In Progress"
        case .testflight: return "TestFlight"
        case .completed: return "Completed"
        case .rejected: return "Rejected"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .testflight: return "airplane"
        case .completed: return "checkmark.seal.fill"
        case .rejected: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .approved: return "blue"
        case .inProgress: return "orange"
        case .testflight: return "cyan"
        case .completed: return "green"
        case .rejected: return "red"
        }
    }
}

nonisolated
enum FeedbackCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case featureRequest = "feature_request"
    case bugReport = "bug_report"
    case improvement
    case other

    var displayName: String {
        switch self {
        case .featureRequest: return "Feature Request"
        case .bugReport: return "Bug Report"
        case .improvement: return "Improvement"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .featureRequest: return "lightbulb"
        case .bugReport: return "ladybug"
        case .improvement: return "arrow.up.circle"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Request DTOs

nonisolated
struct UpdateFeedbackRequest: Encodable, Sendable {
    let title: String?
    let description: String?
    let status: FeedbackStatus?
    let category: FeedbackCategory?
}

nonisolated
struct CreateCommentRequest: Encodable, Sendable {
    let content: String
    let userId: String
    let isAdmin: Bool?
}

nonisolated
struct CreateFeedbackRequest: Encodable, Sendable {
    let title: String
    let description: String
    let category: FeedbackCategory
    let userId: String
    let userEmail: String?
}

// MARK: - Merge DTOs

nonisolated
struct MergeFeedbackRequest: Encodable, Sendable {
    let primaryFeedbackId: UUID
    let secondaryFeedbackIds: [UUID]
}

nonisolated
struct MergeFeedbackResponse: Codable, Sendable {
    let primaryFeedback: Feedback
    let mergedCount: Int
    let totalVotes: Int
    let totalComments: Int
}
