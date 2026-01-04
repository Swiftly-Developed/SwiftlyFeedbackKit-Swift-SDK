import Foundation

// MARK: - Feedback

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

    /// Formatted total MRR string for display (always shows, even if $0)
    var formattedMrr: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalMrr ?? 0)) ?? "$0"
    }
}

// MARK: - Comment

struct Comment: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let content: String
    let userId: String
    let isAdmin: Bool
    let createdAt: Date?
}

// MARK: - Enums

enum FeedbackStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case pending
    case approved
    case inProgress = "in_progress"
    case completed
    case rejected

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .rejected: return "Rejected"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .approved: return "checkmark.circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.seal.fill"
        case .rejected: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .pending: return "gray"
        case .approved: return "blue"
        case .inProgress: return "orange"
        case .completed: return "green"
        case .rejected: return "red"
        }
    }
}

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

struct UpdateFeedbackRequest: Encodable {
    let title: String?
    let description: String?
    let status: FeedbackStatus?
    let category: FeedbackCategory?
}

struct CreateCommentRequest: Encodable {
    let content: String
    let userId: String
    let isAdmin: Bool?
}

struct CreateFeedbackRequest: Encodable {
    let title: String
    let description: String
    let category: FeedbackCategory
    let userId: String
    let userEmail: String?
}
