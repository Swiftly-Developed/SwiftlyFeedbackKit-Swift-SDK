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
        allowedStatuses: [String]
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
