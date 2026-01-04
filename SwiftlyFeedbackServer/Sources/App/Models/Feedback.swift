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

    /// Whether this feedback has been merged into another
    var isMerged: Bool {
        mergedIntoId != nil
    }

    /// Whether this feedback has received merges from other feedback
    var hasMergedFeedback: Bool {
        mergedFeedbackIds?.isEmpty == false
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
}

enum FeedbackCategory: String, Codable {
    case featureRequest = "feature_request"
    case bugReport = "bug_report"
    case improvement
    case other
}
