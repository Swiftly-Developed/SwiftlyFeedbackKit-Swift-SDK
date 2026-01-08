import Foundation

// MARK: - Project Models
//
// All models are marked `nonisolated` to opt out of the project's default MainActor isolation.
// This allows their Codable conformances to be used from any actor context (e.g., AdminAPIClient).

nonisolated
struct Project: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let name: String
    let apiKey: String
    let description: String?
    let ownerId: UUID
    let ownerEmail: String?
    let isArchived: Bool
    let archivedAt: Date?
    let colorIndex: Int
    let feedbackCount: Int
    let memberCount: Int
    let createdAt: Date?
    let updatedAt: Date?
    let slackWebhookUrl: String?
    let slackNotifyNewFeedback: Bool
    let slackNotifyNewComments: Bool
    let slackNotifyStatusChanges: Bool
    let slackIsActive: Bool
    let allowedStatuses: [String]
    // GitHub integration fields
    let githubOwner: String?
    let githubRepo: String?
    let githubToken: String?
    let githubDefaultLabels: [String]?
    let githubSyncStatus: Bool
    let githubIsActive: Bool
    // ClickUp integration fields
    let clickupToken: String?
    let clickupListId: String?
    let clickupWorkspaceName: String?
    let clickupListName: String?
    let clickupDefaultTags: [String]?
    let clickupSyncStatus: Bool
    let clickupSyncComments: Bool
    let clickupVotesFieldId: String?
    let clickupIsActive: Bool
    // Notion integration fields
    let notionToken: String?
    let notionDatabaseId: String?
    let notionDatabaseName: String?
    let notionSyncStatus: Bool
    let notionSyncComments: Bool
    let notionStatusProperty: String?
    let notionVotesProperty: String?
    let notionIsActive: Bool
    // Monday.com integration fields
    let mondayToken: String?
    let mondayBoardId: String?
    let mondayBoardName: String?
    let mondayGroupId: String?
    let mondayGroupName: String?
    let mondaySyncStatus: Bool
    let mondaySyncComments: Bool
    let mondayStatusColumnId: String?
    let mondayVotesColumnId: String?
    let mondayIsActive: Bool
    // Linear integration fields
    let linearToken: String?
    let linearTeamId: String?
    let linearTeamName: String?
    let linearProjectId: String?
    let linearProjectName: String?
    let linearDefaultLabelIds: [String]?
    let linearSyncStatus: Bool
    let linearSyncComments: Bool
    let linearIsActive: Bool

    /// Whether Slack integration is configured (has webhook URL)
    var isSlackConfigured: Bool {
        slackWebhookUrl != nil && !slackWebhookUrl!.isEmpty
    }

    /// Whether Slack integration is active (configured AND enabled)
    var isSlackActive: Bool {
        isSlackConfigured && slackIsActive
    }

    /// Whether GitHub integration is configured (has required fields)
    var isGitHubConfigured: Bool {
        githubOwner != nil && githubRepo != nil && githubToken != nil
    }

    /// Whether GitHub integration is active (configured AND enabled)
    var isGitHubActive: Bool {
        isGitHubConfigured && githubIsActive
    }

    /// Whether ClickUp integration is configured (has required fields)
    var isClickUpConfigured: Bool {
        clickupToken != nil && clickupListId != nil
    }

    /// Whether ClickUp integration is active (configured AND enabled)
    var isClickUpActive: Bool {
        isClickUpConfigured && clickupIsActive
    }

    /// Whether Notion integration is configured (has required fields)
    var isNotionConfigured: Bool {
        notionToken != nil && notionDatabaseId != nil
    }

    /// Whether Notion integration is active (configured AND enabled)
    var isNotionActive: Bool {
        isNotionConfigured && notionIsActive
    }

    /// Whether Monday.com integration is configured (has required fields)
    var isMondayConfigured: Bool {
        mondayToken != nil && mondayBoardId != nil
    }

    /// Whether Monday.com integration is active (configured AND enabled)
    var isMondayActive: Bool {
        isMondayConfigured && mondayIsActive
    }

    /// Whether Linear integration is configured (has required fields)
    var isLinearConfigured: Bool {
        linearToken != nil && linearTeamId != nil
    }

    /// Whether Linear integration is active (configured AND enabled)
    var isLinearActive: Bool {
        isLinearConfigured && linearIsActive
    }

    /// Whether any integration is configured
    var hasAnyIntegration: Bool {
        isSlackConfigured || isGitHubConfigured || isClickUpConfigured || isNotionConfigured || isMondayConfigured || isLinearConfigured
    }

    /// Whether any integration is active
    var hasAnyActiveIntegration: Bool {
        isSlackActive || isGitHubActive || isClickUpActive || isNotionActive || isMondayActive || isLinearActive
    }

    // Custom decoder to handle backwards compatibility when allowedStatuses is missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        ownerId = try container.decode(UUID.self, forKey: .ownerId)
        ownerEmail = try container.decodeIfPresent(String.self, forKey: .ownerEmail)
        isArchived = try container.decode(Bool.self, forKey: .isArchived)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        colorIndex = try container.decode(Int.self, forKey: .colorIndex)
        feedbackCount = try container.decode(Int.self, forKey: .feedbackCount)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        slackWebhookUrl = try container.decodeIfPresent(String.self, forKey: .slackWebhookUrl)
        slackNotifyNewFeedback = try container.decode(Bool.self, forKey: .slackNotifyNewFeedback)
        slackNotifyNewComments = try container.decode(Bool.self, forKey: .slackNotifyNewComments)
        slackNotifyStatusChanges = try container.decode(Bool.self, forKey: .slackNotifyStatusChanges)
        slackIsActive = try container.decodeIfPresent(Bool.self, forKey: .slackIsActive) ?? true
        // Default to standard statuses if not present (backwards compatibility)
        allowedStatuses = try container.decodeIfPresent([String].self, forKey: .allowedStatuses)
            ?? ["pending", "approved", "in_progress", "completed", "rejected"]
        // GitHub fields (backwards compatibility)
        githubOwner = try container.decodeIfPresent(String.self, forKey: .githubOwner)
        githubRepo = try container.decodeIfPresent(String.self, forKey: .githubRepo)
        githubToken = try container.decodeIfPresent(String.self, forKey: .githubToken)
        githubDefaultLabels = try container.decodeIfPresent([String].self, forKey: .githubDefaultLabels)
        githubSyncStatus = try container.decodeIfPresent(Bool.self, forKey: .githubSyncStatus) ?? false
        githubIsActive = try container.decodeIfPresent(Bool.self, forKey: .githubIsActive) ?? true
        // ClickUp fields (backwards compatibility)
        clickupToken = try container.decodeIfPresent(String.self, forKey: .clickupToken)
        clickupListId = try container.decodeIfPresent(String.self, forKey: .clickupListId)
        clickupWorkspaceName = try container.decodeIfPresent(String.self, forKey: .clickupWorkspaceName)
        clickupListName = try container.decodeIfPresent(String.self, forKey: .clickupListName)
        clickupDefaultTags = try container.decodeIfPresent([String].self, forKey: .clickupDefaultTags)
        clickupSyncStatus = try container.decodeIfPresent(Bool.self, forKey: .clickupSyncStatus) ?? false
        clickupSyncComments = try container.decodeIfPresent(Bool.self, forKey: .clickupSyncComments) ?? false
        clickupVotesFieldId = try container.decodeIfPresent(String.self, forKey: .clickupVotesFieldId)
        clickupIsActive = try container.decodeIfPresent(Bool.self, forKey: .clickupIsActive) ?? true
        // Notion fields (backwards compatibility)
        notionToken = try container.decodeIfPresent(String.self, forKey: .notionToken)
        notionDatabaseId = try container.decodeIfPresent(String.self, forKey: .notionDatabaseId)
        notionDatabaseName = try container.decodeIfPresent(String.self, forKey: .notionDatabaseName)
        notionSyncStatus = try container.decodeIfPresent(Bool.self, forKey: .notionSyncStatus) ?? false
        notionSyncComments = try container.decodeIfPresent(Bool.self, forKey: .notionSyncComments) ?? false
        notionStatusProperty = try container.decodeIfPresent(String.self, forKey: .notionStatusProperty)
        notionVotesProperty = try container.decodeIfPresent(String.self, forKey: .notionVotesProperty)
        notionIsActive = try container.decodeIfPresent(Bool.self, forKey: .notionIsActive) ?? true
        // Monday.com fields (backwards compatibility)
        mondayToken = try container.decodeIfPresent(String.self, forKey: .mondayToken)
        mondayBoardId = try container.decodeIfPresent(String.self, forKey: .mondayBoardId)
        mondayBoardName = try container.decodeIfPresent(String.self, forKey: .mondayBoardName)
        mondayGroupId = try container.decodeIfPresent(String.self, forKey: .mondayGroupId)
        mondayGroupName = try container.decodeIfPresent(String.self, forKey: .mondayGroupName)
        mondaySyncStatus = try container.decodeIfPresent(Bool.self, forKey: .mondaySyncStatus) ?? false
        mondaySyncComments = try container.decodeIfPresent(Bool.self, forKey: .mondaySyncComments) ?? false
        mondayStatusColumnId = try container.decodeIfPresent(String.self, forKey: .mondayStatusColumnId)
        mondayVotesColumnId = try container.decodeIfPresent(String.self, forKey: .mondayVotesColumnId)
        mondayIsActive = try container.decodeIfPresent(Bool.self, forKey: .mondayIsActive) ?? true
        // Linear fields (backwards compatibility)
        linearToken = try container.decodeIfPresent(String.self, forKey: .linearToken)
        linearTeamId = try container.decodeIfPresent(String.self, forKey: .linearTeamId)
        linearTeamName = try container.decodeIfPresent(String.self, forKey: .linearTeamName)
        linearProjectId = try container.decodeIfPresent(String.self, forKey: .linearProjectId)
        linearProjectName = try container.decodeIfPresent(String.self, forKey: .linearProjectName)
        linearDefaultLabelIds = try container.decodeIfPresent([String].self, forKey: .linearDefaultLabelIds)
        linearSyncStatus = try container.decodeIfPresent(Bool.self, forKey: .linearSyncStatus) ?? false
        linearSyncComments = try container.decodeIfPresent(Bool.self, forKey: .linearSyncComments) ?? false
        linearIsActive = try container.decodeIfPresent(Bool.self, forKey: .linearIsActive) ?? true
    }

    init(
        id: UUID,
        name: String,
        apiKey: String,
        description: String?,
        ownerId: UUID,
        ownerEmail: String?,
        isArchived: Bool,
        archivedAt: Date?,
        colorIndex: Int,
        feedbackCount: Int,
        memberCount: Int,
        createdAt: Date?,
        updatedAt: Date?,
        slackWebhookUrl: String?,
        slackNotifyNewFeedback: Bool,
        slackNotifyNewComments: Bool,
        slackNotifyStatusChanges: Bool,
        slackIsActive: Bool = true,
        allowedStatuses: [String],
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
        linearIsActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.apiKey = apiKey
        self.description = description
        self.ownerId = ownerId
        self.ownerEmail = ownerEmail
        self.isArchived = isArchived
        self.archivedAt = archivedAt
        self.colorIndex = colorIndex
        self.feedbackCount = feedbackCount
        self.memberCount = memberCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.slackWebhookUrl = slackWebhookUrl
        self.slackNotifyNewFeedback = slackNotifyNewFeedback
        self.slackNotifyNewComments = slackNotifyNewComments
        self.slackNotifyStatusChanges = slackNotifyStatusChanges
        self.slackIsActive = slackIsActive
        self.allowedStatuses = allowedStatuses
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
    }
}

nonisolated
struct ProjectListItem: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String?
    let isArchived: Bool
    let isOwner: Bool
    let role: ProjectRole?
    let colorIndex: Int
    let feedbackCount: Int
    let createdAt: Date?
}

extension ProjectListItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ProjectListItem, rhs: ProjectListItem) -> Bool {
        lhs.id == rhs.id
    }
}

nonisolated
struct ProjectMember: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    let userEmail: String
    let userName: String
    let role: ProjectRole
    let createdAt: Date?
}

nonisolated
enum ProjectRole: String, Codable, CaseIterable, Sendable, Hashable {
    case admin
    case member
    case viewer

    var displayName: String {
        switch self {
        case .admin: return "Admin"
        case .member: return "Member"
        case .viewer: return "Viewer"
        }
    }

    var roleDescription: String {
        switch self {
        case .admin: return "Can manage project settings and members"
        case .member: return "Can view and respond to feedback"
        case .viewer: return "Can only view feedback"
        }
    }
}

nonisolated
struct CreateProjectRequest: Encodable, Sendable {
    let name: String
    let description: String?
}

nonisolated
struct UpdateProjectRequest: Encodable, Sendable {
    let name: String?
    let description: String?
    let colorIndex: Int?
}

nonisolated
struct UpdateProjectSlackRequest: Encodable, Sendable {
    let slackWebhookUrl: String?
    let slackNotifyNewFeedback: Bool?
    let slackNotifyNewComments: Bool?
    let slackNotifyStatusChanges: Bool?
    let slackIsActive: Bool?
}

nonisolated
struct UpdateProjectStatusesRequest: Encodable, Sendable {
    let allowedStatuses: [String]
}

// MARK: - GitHub Integration

nonisolated
struct UpdateProjectGitHubRequest: Encodable, Sendable {
    let githubOwner: String?
    let githubRepo: String?
    let githubToken: String?
    let githubDefaultLabels: [String]?
    let githubSyncStatus: Bool?
    let githubIsActive: Bool?
}

nonisolated
struct CreateGitHubIssueRequest: Encodable, Sendable {
    let feedbackId: UUID
    let additionalLabels: [String]?
}

nonisolated
struct CreateGitHubIssueResponse: Decodable, Sendable {
    let feedbackId: UUID
    let issueUrl: String
    let issueNumber: Int
}

nonisolated
struct BulkCreateGitHubIssuesRequest: Encodable, Sendable {
    let feedbackIds: [UUID]
    let additionalLabels: [String]?
}

nonisolated
struct BulkCreateGitHubIssuesResponse: Decodable, Sendable {
    let created: [CreateGitHubIssueResponse]
    let failed: [UUID]
}

// MARK: - ClickUp Integration

nonisolated
struct UpdateProjectClickUpRequest: Encodable, Sendable {
    let clickupToken: String?
    let clickupListId: String?
    let clickupWorkspaceName: String?
    let clickupListName: String?
    let clickupDefaultTags: [String]?
    let clickupSyncStatus: Bool?
    let clickupSyncComments: Bool?
    let clickupVotesFieldId: String?
    let clickupIsActive: Bool?
}

nonisolated
struct CreateClickUpTaskRequest: Encodable, Sendable {
    let feedbackId: UUID
    let additionalTags: [String]?
}

nonisolated
struct CreateClickUpTaskResponse: Decodable, Sendable {
    let feedbackId: UUID
    let taskUrl: String
    let taskId: String
}

nonisolated
struct BulkCreateClickUpTasksRequest: Encodable, Sendable {
    let feedbackIds: [UUID]
    let additionalTags: [String]?
}

nonisolated
struct BulkCreateClickUpTasksResponse: Decodable, Sendable {
    let created: [CreateClickUpTaskResponse]
    let failed: [UUID]
}

// ClickUp hierarchy models
nonisolated
struct ClickUpWorkspace: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
}

nonisolated
struct ClickUpSpace: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
}

nonisolated
struct ClickUpFolder: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
}

nonisolated
struct ClickUpList: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
}

nonisolated
struct ClickUpCustomField: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let type: String
}

nonisolated
struct AddMemberRequest: Encodable, Sendable {
    let email: String
    let role: ProjectRole
}

nonisolated
struct UpdateMemberRoleRequest: Encodable, Sendable {
    let role: ProjectRole
}

nonisolated
struct ProjectInvite: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let email: String
    let role: ProjectRole
    let code: String?
    let expiresAt: Date
    let createdAt: Date?
}

nonisolated
struct AddMemberResponse: Codable, Sendable {
    let member: ProjectMember?
    let invite: ProjectInvite?
    let inviteSent: Bool
}

nonisolated
struct AcceptInviteRequest: Encodable, Sendable {
    let code: String
}

nonisolated
struct InvitePreview: Codable, Sendable {
    let projectName: String
    let projectDescription: String?
    let invitedByName: String
    let role: ProjectRole
    let expiresAt: Date
    let emailMatches: Bool
    let inviteEmail: String
}

nonisolated
struct AcceptInviteResponse: Codable, Sendable {
    let projectId: UUID
    let projectName: String
    let role: ProjectRole
}

// MARK: - Notion Integration

nonisolated
struct UpdateProjectNotionRequest: Encodable, Sendable {
    let notionToken: String?
    let notionDatabaseId: String?
    let notionDatabaseName: String?
    let notionSyncStatus: Bool?
    let notionSyncComments: Bool?
    let notionStatusProperty: String?
    let notionVotesProperty: String?
    let notionIsActive: Bool?
}

nonisolated
struct CreateNotionPageRequest: Encodable, Sendable {
    let feedbackId: UUID
}

nonisolated
struct CreateNotionPageResponse: Decodable, Sendable {
    let feedbackId: UUID
    let pageUrl: String
    let pageId: String
}

nonisolated
struct BulkCreateNotionPagesRequest: Encodable, Sendable {
    let feedbackIds: [UUID]
}

nonisolated
struct BulkCreateNotionPagesResponse: Decodable, Sendable {
    let created: [CreateNotionPageResponse]
    let failed: [UUID]
}

nonisolated
struct NotionDatabase: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let properties: [NotionProperty]
}

nonisolated
struct NotionProperty: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let type: String
}

// MARK: - Monday.com Integration

nonisolated
struct UpdateProjectMondayRequest: Encodable, Sendable {
    let mondayToken: String?
    let mondayBoardId: String?
    let mondayBoardName: String?
    let mondayGroupId: String?
    let mondayGroupName: String?
    let mondaySyncStatus: Bool?
    let mondaySyncComments: Bool?
    let mondayStatusColumnId: String?
    let mondayVotesColumnId: String?
    let mondayIsActive: Bool?
}

nonisolated
struct CreateMondayItemRequest: Encodable, Sendable {
    let feedbackId: UUID
}

nonisolated
struct CreateMondayItemResponse: Decodable, Sendable {
    let feedbackId: UUID
    let itemUrl: String
    let itemId: String
}

nonisolated
struct BulkCreateMondayItemsRequest: Encodable, Sendable {
    let feedbackIds: [UUID]
}

nonisolated
struct BulkCreateMondayItemsResponse: Decodable, Sendable {
    let created: [CreateMondayItemResponse]
    let failed: [UUID]
}

nonisolated
struct MondayBoard: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
}

nonisolated
struct MondayGroup: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let title: String
}

nonisolated
struct MondayColumn: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let title: String
    let type: String
}

// MARK: - Linear Integration

nonisolated
struct UpdateProjectLinearRequest: Encodable, Sendable {
    let linearToken: String?
    let linearTeamId: String?
    let linearTeamName: String?
    let linearProjectId: String?
    let linearProjectName: String?
    let linearDefaultLabelIds: [String]?
    let linearSyncStatus: Bool?
    let linearSyncComments: Bool?
    let linearIsActive: Bool?
}

nonisolated
struct CreateLinearIssueRequest: Encodable, Sendable {
    let feedbackId: UUID
    let additionalLabelIds: [String]?
}

nonisolated
struct CreateLinearIssueResponse: Decodable, Sendable {
    let feedbackId: UUID
    let issueUrl: String
    let issueId: String
    let identifier: String
}

nonisolated
struct BulkCreateLinearIssuesRequest: Encodable, Sendable {
    let feedbackIds: [UUID]
    let additionalLabelIds: [String]?
}

nonisolated
struct BulkCreateLinearIssuesResponse: Decodable, Sendable {
    let created: [CreateLinearIssueResponse]
    let failed: [UUID]
}

// Linear hierarchy models
nonisolated
struct LinearTeam: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let key: String
}

nonisolated
struct LinearProject: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let state: String
}

nonisolated
struct LinearWorkflowState: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let type: String
    let position: Double
}

nonisolated
struct LinearLabel: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let name: String
    let color: String
}
