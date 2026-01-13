import Fluent
import Vapor

final class Feedback: Model, Content, @unchecked Sendable {
    static let schema = "feedbacks"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "description")
    var description: String

    @Enum(key: "status")
    var status: FeedbackStatus

    @Enum(key: "category")
    var category: FeedbackCategory

    @Field(key: "user_id")
    var userId: String

    @Field(key: "user_email")
    var userEmail: String?

    @Field(key: "vote_count")
    var voteCount: Int

    @Parent(key: "project_id")
    var project: Project

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$feedback)
    var votes: [Vote]

    @Children(for: \.$feedback)
    var comments: [Comment]

    // Merge-related fields
    @OptionalField(key: "merged_into_id")
    var mergedIntoId: UUID?

    @OptionalField(key: "merged_at")
    var mergedAt: Date?

    @OptionalField(key: "merged_feedback_ids")
    var mergedFeedbackIds: [UUID]?

    // GitHub integration fields
    @OptionalField(key: "github_issue_url")
    var githubIssueURL: String?

    @OptionalField(key: "github_issue_number")
    var githubIssueNumber: Int?

    // ClickUp integration fields
    @OptionalField(key: "clickup_task_url")
    var clickupTaskURL: String?

    @OptionalField(key: "clickup_task_id")
    var clickupTaskId: String?

    // Notion integration fields
    @OptionalField(key: "notion_page_url")
    var notionPageURL: String?

    @OptionalField(key: "notion_page_id")
    var notionPageId: String?

    // Monday.com integration fields
    @OptionalField(key: "monday_item_url")
    var mondayItemURL: String?

    @OptionalField(key: "monday_item_id")
    var mondayItemId: String?

    // Linear integration fields
    @OptionalField(key: "linear_issue_url")
    var linearIssueURL: String?

    @OptionalField(key: "linear_issue_id")
    var linearIssueId: String?

    // Trello integration fields
    @OptionalField(key: "trello_card_url")
    var trelloCardURL: String?

    @OptionalField(key: "trello_card_id")
    var trelloCardId: String?

    /// Whether this feedback has been merged into another
    var isMerged: Bool {
        mergedIntoId != nil
    }

    /// Whether this feedback has received merges from other feedback
    var hasMergedFeedback: Bool {
        mergedFeedbackIds?.isEmpty == false
    }

    /// Whether this feedback has a linked GitHub issue
    var hasGitHubIssue: Bool {
        githubIssueURL != nil
    }

    /// Whether this feedback has a linked ClickUp task
    var hasClickUpTask: Bool {
        clickupTaskURL != nil
    }

    /// Whether this feedback has a linked Notion page
    var hasNotionPage: Bool {
        notionPageURL != nil
    }

    /// Whether this feedback has a linked Monday.com item
    var hasMondayItem: Bool {
        mondayItemURL != nil
    }

    /// Whether this feedback has a linked Linear issue
    var hasLinearIssue: Bool {
        linearIssueURL != nil
    }

    /// Whether this feedback has a linked Trello card
    var hasTrelloCard: Bool {
        trelloCardURL != nil
    }

    init() {}

    init(
        id: UUID? = nil,
        title: String,
        description: String,
        status: FeedbackStatus = .pending,
        category: FeedbackCategory = .featureRequest,
        userId: String,
        userEmail: String? = nil,
        voteCount: Int = 0,
        projectId: UUID
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.category = category
        self.userId = userId
        self.userEmail = userEmail
        self.voteCount = voteCount
        self.$project.id = projectId
    }
}

enum FeedbackStatus: String, Codable, CaseIterable {
    case pending
    case approved
    case inProgress = "in_progress"
    case testflight
    case completed
    case rejected

    /// All statuses that are enabled by default for new projects
    static var defaultAllowed: [FeedbackStatus] {
        [.pending, .approved, .inProgress, .completed, .rejected]
    }

    /// Maps SwiftlyFeedback status to ClickUp status names
    /// Note: These should match the status names configured in the user's ClickUp list
    var clickupStatusName: String {
        switch self {
        case .pending:
            return "to do"
        case .approved:
            return "approved"
        case .inProgress:
            return "in progress"
        case .testflight:
            return "in review"
        case .completed:
            return "complete"
        case .rejected:
            return "closed"
        }
    }

    /// Maps SwiftlyFeedback status to Notion status names
    var notionStatusName: String {
        switch self {
        case .pending:
            return "To Do"
        case .approved:
            return "Approved"
        case .inProgress:
            return "In Progress"
        case .testflight:
            return "In Review"
        case .completed:
            return "Complete"
        case .rejected:
            return "Closed"
        }
    }

    /// Maps SwiftlyFeedback status to Monday.com status label names
    var mondayStatusName: String {
        switch self {
        case .pending:
            return "Pending"
        case .approved:
            return "Approved"
        case .inProgress:
            return "Working on it"
        case .testflight:
            return "In Review"
        case .completed:
            return "Done"
        case .rejected:
            return "Stuck"
        }
    }

    /// Maps SwiftlyFeedback status to Linear workflow state types
    /// Linear states have types: backlog, unstarted, started, completed, canceled
    var linearStateType: String {
        switch self {
        case .pending:
            return "backlog"
        case .approved:
            return "unstarted"
        case .inProgress:
            return "started"
        case .testflight:
            return "started"
        case .completed:
            return "completed"
        case .rejected:
            return "canceled"
        }
    }
}

enum FeedbackCategory: String, Codable {
    case featureRequest = "feature_request"
    case bugReport = "bug_report"
    case improvement
    case other
}
