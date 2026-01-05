import Foundation

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
    let allowedStatuses: [String]
    // GitHub integration fields
    let githubOwner: String?
    let githubRepo: String?
    let githubToken: String?
    let githubDefaultLabels: [String]?
    let githubSyncStatus: Bool
    // ClickUp integration fields
    let clickupToken: String?
    let clickupListId: String?
    let clickupWorkspaceName: String?
    let clickupListName: String?
    let clickupDefaultTags: [String]?
    let clickupSyncStatus: Bool
    let clickupSyncComments: Bool
    let clickupVotesFieldId: String?

    /// Whether GitHub integration is configured
    var isGitHubConfigured: Bool {
        githubOwner != nil && githubRepo != nil && githubToken != nil
    }

    /// Whether ClickUp integration is configured
    var isClickUpConfigured: Bool {
        clickupToken != nil && clickupListId != nil
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
        // Default to standard statuses if not present (backwards compatibility)
        allowedStatuses = try container.decodeIfPresent([String].self, forKey: .allowedStatuses)
            ?? ["pending", "approved", "in_progress", "completed", "rejected"]
        // GitHub fields (backwards compatibility)
        githubOwner = try container.decodeIfPresent(String.self, forKey: .githubOwner)
        githubRepo = try container.decodeIfPresent(String.self, forKey: .githubRepo)
        githubToken = try container.decodeIfPresent(String.self, forKey: .githubToken)
        githubDefaultLabels = try container.decodeIfPresent([String].self, forKey: .githubDefaultLabels)
        githubSyncStatus = try container.decodeIfPresent(Bool.self, forKey: .githubSyncStatus) ?? false
        // ClickUp fields (backwards compatibility)
        clickupToken = try container.decodeIfPresent(String.self, forKey: .clickupToken)
        clickupListId = try container.decodeIfPresent(String.self, forKey: .clickupListId)
        clickupWorkspaceName = try container.decodeIfPresent(String.self, forKey: .clickupWorkspaceName)
        clickupListName = try container.decodeIfPresent(String.self, forKey: .clickupListName)
        clickupDefaultTags = try container.decodeIfPresent([String].self, forKey: .clickupDefaultTags)
        clickupSyncStatus = try container.decodeIfPresent(Bool.self, forKey: .clickupSyncStatus) ?? false
        clickupSyncComments = try container.decodeIfPresent(Bool.self, forKey: .clickupSyncComments) ?? false
        clickupVotesFieldId = try container.decodeIfPresent(String.self, forKey: .clickupVotesFieldId)
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
        allowedStatuses: [String],
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
        self.allowedStatuses = allowedStatuses
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

struct ProjectMember: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    let userEmail: String
    let userName: String
    let role: ProjectRole
    let createdAt: Date?
}

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

struct CreateProjectRequest: Encodable {
    let name: String
    let description: String?
}

struct UpdateProjectRequest: Encodable {
    let name: String?
    let description: String?
    let colorIndex: Int?
}

struct UpdateProjectSlackRequest: Encodable {
    let slackWebhookUrl: String?
    let slackNotifyNewFeedback: Bool?
    let slackNotifyNewComments: Bool?
    let slackNotifyStatusChanges: Bool?
}

struct UpdateProjectStatusesRequest: Encodable {
    let allowedStatuses: [String]
}

// MARK: - GitHub Integration

struct UpdateProjectGitHubRequest: Encodable {
    let githubOwner: String?
    let githubRepo: String?
    let githubToken: String?
    let githubDefaultLabels: [String]?
    let githubSyncStatus: Bool?
}

struct CreateGitHubIssueRequest: Encodable {
    let feedbackId: UUID
    let additionalLabels: [String]?
}

struct CreateGitHubIssueResponse: Decodable {
    let feedbackId: UUID
    let issueUrl: String
    let issueNumber: Int
}

struct BulkCreateGitHubIssuesRequest: Encodable {
    let feedbackIds: [UUID]
    let additionalLabels: [String]?
}

struct BulkCreateGitHubIssuesResponse: Decodable {
    let created: [CreateGitHubIssueResponse]
    let failed: [UUID]
}

// MARK: - ClickUp Integration

struct UpdateProjectClickUpRequest: Encodable {
    let clickupToken: String?
    let clickupListId: String?
    let clickupWorkspaceName: String?
    let clickupListName: String?
    let clickupDefaultTags: [String]?
    let clickupSyncStatus: Bool?
    let clickupSyncComments: Bool?
    let clickupVotesFieldId: String?
}

struct CreateClickUpTaskRequest: Encodable {
    let feedbackId: UUID
    let additionalTags: [String]?
}

struct CreateClickUpTaskResponse: Decodable {
    let feedbackId: UUID
    let taskUrl: String
    let taskId: String
}

struct BulkCreateClickUpTasksRequest: Encodable {
    let feedbackIds: [UUID]
    let additionalTags: [String]?
}

struct BulkCreateClickUpTasksResponse: Decodable {
    let created: [CreateClickUpTaskResponse]
    let failed: [UUID]
}

// ClickUp hierarchy models
struct ClickUpWorkspace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct ClickUpSpace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct ClickUpFolder: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct ClickUpList: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct ClickUpCustomField: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
}

struct AddMemberRequest: Encodable {
    let email: String
    let role: ProjectRole
}

struct UpdateMemberRoleRequest: Encodable {
    let role: ProjectRole
}

struct ProjectInvite: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let email: String
    let role: ProjectRole
    let code: String?
    let expiresAt: Date
    let createdAt: Date?
}

struct AddMemberResponse: Codable, Sendable {
    let member: ProjectMember?
    let invite: ProjectInvite?
    let inviteSent: Bool
}

struct AcceptInviteRequest: Encodable {
    let code: String
}

struct InvitePreview: Codable, Sendable {
    let projectName: String
    let projectDescription: String?
    let invitedByName: String
    let role: ProjectRole
    let expiresAt: Date
    let emailMatches: Bool
    let inviteEmail: String
}

struct AcceptInviteResponse: Codable, Sendable {
    let projectId: UUID
    let projectName: String
    let role: ProjectRole
}
