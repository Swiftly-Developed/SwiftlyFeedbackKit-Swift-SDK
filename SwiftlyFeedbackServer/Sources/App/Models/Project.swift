import Fluent
import Vapor

final class Project: Model, Content, @unchecked Sendable {
    static let schema = "projects"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "api_key")
    var apiKey: String

    @Field(key: "description")
    var description: String?

    @Parent(key: "owner_id")
    var owner: User

    @Field(key: "is_archived")
    var isArchived: Bool

    @OptionalField(key: "archived_at")
    var archivedAt: Date?

    @Field(key: "color_index")
    var colorIndex: Int

    @OptionalField(key: "slack_webhook_url")
    var slackWebhookURL: String?

    @Field(key: "slack_notify_new_feedback")
    var slackNotifyNewFeedback: Bool

    @Field(key: "slack_notify_new_comments")
    var slackNotifyNewComments: Bool

    @Field(key: "slack_notify_status_changes")
    var slackNotifyStatusChanges: Bool

    @Field(key: "allowed_statuses")
    var allowedStatuses: [String]

    // GitHub integration fields
    @OptionalField(key: "github_owner")
    var githubOwner: String?

    @OptionalField(key: "github_repo")
    var githubRepo: String?

    @OptionalField(key: "github_token")
    var githubToken: String?

    @OptionalField(key: "github_default_labels")
    var githubDefaultLabels: [String]?

    @Field(key: "github_sync_status")
    var githubSyncStatus: Bool

    // ClickUp integration fields
    @OptionalField(key: "clickup_token")
    var clickupToken: String?

    @OptionalField(key: "clickup_list_id")
    var clickupListId: String?

    @OptionalField(key: "clickup_workspace_name")
    var clickupWorkspaceName: String?

    @OptionalField(key: "clickup_list_name")
    var clickupListName: String?

    @OptionalField(key: "clickup_default_tags")
    var clickupDefaultTags: [String]?

    @Field(key: "clickup_sync_status")
    var clickupSyncStatus: Bool

    @Field(key: "clickup_sync_comments")
    var clickupSyncComments: Bool

    @OptionalField(key: "clickup_votes_field_id")
    var clickupVotesFieldId: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    @Children(for: \.$project)
    var feedbacks: [Feedback]

    @Siblings(through: ProjectMember.self, from: \.$project, to: \.$user)
    var members: [User]

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        apiKey: String,
        description: String? = nil,
        ownerId: UUID,
        isArchived: Bool = false,
        colorIndex: Int = 0,
        slackWebhookURL: String? = nil,
        slackNotifyNewFeedback: Bool = true,
        slackNotifyNewComments: Bool = true,
        slackNotifyStatusChanges: Bool = true,
        allowedStatuses: [String]? = nil,
        githubOwner: String? = nil,
        githubRepo: String? = nil,
        githubToken: String? = nil,
        githubDefaultLabels: [String]? = nil,
        githubSyncStatus: Bool = false,
        clickupToken: String? = nil,
        clickupListId: String? = nil,
        clickupWorkspaceName: String? = nil,
        clickupListName: String? = nil,
        clickupDefaultTags: [String]? = nil,
        clickupSyncStatus: Bool = false,
        clickupSyncComments: Bool = false,
        clickupVotesFieldId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.apiKey = apiKey
        self.description = description
        self.$owner.id = ownerId
        self.isArchived = isArchived
        self.colorIndex = colorIndex
        self.slackWebhookURL = slackWebhookURL
        self.slackNotifyNewFeedback = slackNotifyNewFeedback
        self.slackNotifyNewComments = slackNotifyNewComments
        self.slackNotifyStatusChanges = slackNotifyStatusChanges
        self.allowedStatuses = allowedStatuses ?? FeedbackStatus.defaultAllowed.map { $0.rawValue }
        self.githubOwner = githubOwner
        self.githubRepo = githubRepo
        self.githubToken = githubToken
        self.githubDefaultLabels = githubDefaultLabels
        self.githubSyncStatus = githubSyncStatus
        self.clickupToken = clickupToken
        self.clickupListId = clickupListId
        self.clickupWorkspaceName = clickupWorkspaceName
        self.clickupListName = clickupListName
        self.clickupDefaultTags = clickupDefaultTags
        self.clickupSyncStatus = clickupSyncStatus
        self.clickupSyncComments = clickupSyncComments
        self.clickupVotesFieldId = clickupVotesFieldId
    }
}

extension Project {
    /// Check if a user has access to this project (owner or member)
    func userHasAccess(_ userId: UUID, on db: Database) async throws -> Bool {
        // Owner always has access
        if $owner.id == userId {
            return true
        }

        // Check if user is a member
        let membership = try await ProjectMember.query(on: db)
            .filter(\.$project.$id == requireID())
            .filter(\.$user.$id == userId)
            .first()

        return membership != nil
    }

    /// Check if a user is the owner of this project
    func userIsOwner(_ userId: UUID) -> Bool {
        $owner.id == userId
    }
}
