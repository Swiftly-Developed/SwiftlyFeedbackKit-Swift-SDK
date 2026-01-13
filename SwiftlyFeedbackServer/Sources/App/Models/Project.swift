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

    @Field(key: "slack_is_active")
    var slackIsActive: Bool

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

    @Field(key: "github_is_active")
    var githubIsActive: Bool

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

    @Field(key: "clickup_is_active")
    var clickupIsActive: Bool

    // Notion integration fields
    @OptionalField(key: "notion_token")
    var notionToken: String?

    @OptionalField(key: "notion_database_id")
    var notionDatabaseId: String?

    @OptionalField(key: "notion_database_name")
    var notionDatabaseName: String?

    @Field(key: "notion_sync_status")
    var notionSyncStatus: Bool

    @Field(key: "notion_sync_comments")
    var notionSyncComments: Bool

    @OptionalField(key: "notion_status_property")
    var notionStatusProperty: String?

    @OptionalField(key: "notion_votes_property")
    var notionVotesProperty: String?

    @Field(key: "notion_is_active")
    var notionIsActive: Bool

    // Monday.com integration fields
    @OptionalField(key: "monday_token")
    var mondayToken: String?

    @OptionalField(key: "monday_board_id")
    var mondayBoardId: String?

    @OptionalField(key: "monday_board_name")
    var mondayBoardName: String?

    @OptionalField(key: "monday_group_id")
    var mondayGroupId: String?

    @OptionalField(key: "monday_group_name")
    var mondayGroupName: String?

    @Field(key: "monday_sync_status")
    var mondaySyncStatus: Bool

    @Field(key: "monday_sync_comments")
    var mondaySyncComments: Bool

    @OptionalField(key: "monday_status_column_id")
    var mondayStatusColumnId: String?

    @OptionalField(key: "monday_votes_column_id")
    var mondayVotesColumnId: String?

    @Field(key: "monday_is_active")
    var mondayIsActive: Bool

    // Linear integration fields
    @OptionalField(key: "linear_token")
    var linearToken: String?

    @OptionalField(key: "linear_team_id")
    var linearTeamId: String?

    @OptionalField(key: "linear_team_name")
    var linearTeamName: String?

    @OptionalField(key: "linear_project_id")
    var linearProjectId: String?

    @OptionalField(key: "linear_project_name")
    var linearProjectName: String?

    @OptionalField(key: "linear_default_label_ids")
    var linearDefaultLabelIds: [String]?

    @Field(key: "linear_sync_status")
    var linearSyncStatus: Bool

    @Field(key: "linear_sync_comments")
    var linearSyncComments: Bool

    @Field(key: "linear_is_active")
    var linearIsActive: Bool

    // Trello integration fields
    @OptionalField(key: "trello_token")
    var trelloToken: String?

    @OptionalField(key: "trello_board_id")
    var trelloBoardId: String?

    @OptionalField(key: "trello_board_name")
    var trelloBoardName: String?

    @OptionalField(key: "trello_list_id")
    var trelloListId: String?

    @OptionalField(key: "trello_list_name")
    var trelloListName: String?

    @Field(key: "trello_sync_status")
    var trelloSyncStatus: Bool

    @Field(key: "trello_sync_comments")
    var trelloSyncComments: Bool

    @Field(key: "trello_is_active")
    var trelloIsActive: Bool

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
        slackIsActive: Bool = true,
        allowedStatuses: [String]? = nil,
        githubOwner: String? = nil,
        githubRepo: String? = nil,
        githubToken: String? = nil,
        githubDefaultLabels: [String]? = nil,
        githubSyncStatus: Bool = false,
        githubIsActive: Bool = true,
        clickupToken: String? = nil,
        clickupListId: String? = nil,
        clickupWorkspaceName: String? = nil,
        clickupListName: String? = nil,
        clickupDefaultTags: [String]? = nil,
        clickupSyncStatus: Bool = false,
        clickupSyncComments: Bool = false,
        clickupVotesFieldId: String? = nil,
        clickupIsActive: Bool = true,
        notionToken: String? = nil,
        notionDatabaseId: String? = nil,
        notionDatabaseName: String? = nil,
        notionSyncStatus: Bool = false,
        notionSyncComments: Bool = false,
        notionStatusProperty: String? = nil,
        notionVotesProperty: String? = nil,
        notionIsActive: Bool = true,
        mondayToken: String? = nil,
        mondayBoardId: String? = nil,
        mondayBoardName: String? = nil,
        mondayGroupId: String? = nil,
        mondayGroupName: String? = nil,
        mondaySyncStatus: Bool = false,
        mondaySyncComments: Bool = false,
        mondayStatusColumnId: String? = nil,
        mondayVotesColumnId: String? = nil,
        mondayIsActive: Bool = true,
        linearToken: String? = nil,
        linearTeamId: String? = nil,
        linearTeamName: String? = nil,
        linearProjectId: String? = nil,
        linearProjectName: String? = nil,
        linearDefaultLabelIds: [String]? = nil,
        linearSyncStatus: Bool = false,
        linearSyncComments: Bool = false,
        linearIsActive: Bool = true,
        trelloToken: String? = nil,
        trelloBoardId: String? = nil,
        trelloBoardName: String? = nil,
        trelloListId: String? = nil,
        trelloListName: String? = nil,
        trelloSyncStatus: Bool = false,
        trelloSyncComments: Bool = false,
        trelloIsActive: Bool = true
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
        self.slackIsActive = slackIsActive
        self.allowedStatuses = allowedStatuses ?? FeedbackStatus.defaultAllowed.map { $0.rawValue }
        self.githubOwner = githubOwner
        self.githubRepo = githubRepo
        self.githubToken = githubToken
        self.githubDefaultLabels = githubDefaultLabels
        self.githubSyncStatus = githubSyncStatus
        self.githubIsActive = githubIsActive
        self.clickupToken = clickupToken
        self.clickupListId = clickupListId
        self.clickupWorkspaceName = clickupWorkspaceName
        self.clickupListName = clickupListName
        self.clickupDefaultTags = clickupDefaultTags
        self.clickupSyncStatus = clickupSyncStatus
        self.clickupSyncComments = clickupSyncComments
        self.clickupVotesFieldId = clickupVotesFieldId
        self.clickupIsActive = clickupIsActive
        self.notionToken = notionToken
        self.notionDatabaseId = notionDatabaseId
        self.notionDatabaseName = notionDatabaseName
        self.notionSyncStatus = notionSyncStatus
        self.notionSyncComments = notionSyncComments
        self.notionStatusProperty = notionStatusProperty
        self.notionVotesProperty = notionVotesProperty
        self.notionIsActive = notionIsActive
        self.mondayToken = mondayToken
        self.mondayBoardId = mondayBoardId
        self.mondayBoardName = mondayBoardName
        self.mondayGroupId = mondayGroupId
        self.mondayGroupName = mondayGroupName
        self.mondaySyncStatus = mondaySyncStatus
        self.mondaySyncComments = mondaySyncComments
        self.mondayStatusColumnId = mondayStatusColumnId
        self.mondayVotesColumnId = mondayVotesColumnId
        self.mondayIsActive = mondayIsActive
        self.linearToken = linearToken
        self.linearTeamId = linearTeamId
        self.linearTeamName = linearTeamName
        self.linearProjectId = linearProjectId
        self.linearProjectName = linearProjectName
        self.linearDefaultLabelIds = linearDefaultLabelIds
        self.linearSyncStatus = linearSyncStatus
        self.linearSyncComments = linearSyncComments
        self.linearIsActive = linearIsActive
        self.trelloToken = trelloToken
        self.trelloBoardId = trelloBoardId
        self.trelloBoardName = trelloBoardName
        self.trelloListId = trelloListId
        self.trelloListName = trelloListName
        self.trelloSyncStatus = trelloSyncStatus
        self.trelloSyncComments = trelloSyncComments
        self.trelloIsActive = trelloIsActive
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
