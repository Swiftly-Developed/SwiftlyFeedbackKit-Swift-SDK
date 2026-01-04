import Vapor

struct CreateProjectDTO: Content, Validatable {
    let name: String
    let description: String?

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty && .count(1...100))
    }
}

struct UpdateProjectDTO: Content, Validatable {
    let name: String?
    let description: String?
    let colorIndex: Int?

    static func validations(_ validations: inout Validations) {
        validations.add("name", as: String?.self, is: .nil || !.empty && .count(1...100), required: false)
        validations.add("colorIndex", as: Int?.self, is: .nil || .range(0...7), required: false)
    }
}

struct UpdateProjectSlackDTO: Content {
    var slackWebhookUrl: String?
    var slackNotifyNewFeedback: Bool?
    var slackNotifyNewComments: Bool?
    var slackNotifyStatusChanges: Bool?
}

struct UpdateProjectStatusesDTO: Content {
    var allowedStatuses: [String]
}

struct AddMemberDTO: Content, Validatable {
    let email: String
    let role: ProjectRole

    static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
    }
}

struct UpdateMemberRoleDTO: Content {
    let role: ProjectRole
}

struct ProjectResponseDTO: Content {
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
    let slackWebhookURL: String?
    let slackNotifyNewFeedback: Bool
    let slackNotifyNewComments: Bool
    let slackNotifyStatusChanges: Bool
    let allowedStatuses: [String]

    init(project: Project, feedbackCount: Int = 0, memberCount: Int = 0, ownerEmail: String? = nil) {
        self.id = project.id!
        self.name = project.name
        self.apiKey = project.apiKey
        self.description = project.description
        self.ownerId = project.$owner.id
        self.ownerEmail = ownerEmail
        self.isArchived = project.isArchived
        self.archivedAt = project.archivedAt
        self.colorIndex = project.colorIndex
        self.feedbackCount = feedbackCount
        self.memberCount = memberCount
        self.createdAt = project.createdAt
        self.updatedAt = project.updatedAt
        self.slackWebhookURL = project.slackWebhookURL
        self.slackNotifyNewFeedback = project.slackNotifyNewFeedback
        self.slackNotifyNewComments = project.slackNotifyNewComments
        self.slackNotifyStatusChanges = project.slackNotifyStatusChanges
        self.allowedStatuses = project.allowedStatuses
    }
}

struct ProjectListItemDTO: Content {
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

struct AddMemberResponse: Content {
    let member: ProjectMember.Public?
    let invite: ProjectInviteDTO?
    let inviteSent: Bool

    init(member: ProjectMember.Public, inviteSent: Bool) {
        self.member = member
        self.invite = nil
        self.inviteSent = inviteSent
    }

    init(invite: ProjectInvite, inviteSent: Bool) {
        self.member = nil
        self.invite = ProjectInviteDTO(invite: invite)
        self.inviteSent = inviteSent
    }
}

struct ProjectInviteDTO: Content {
    let id: UUID
    let email: String
    let role: ProjectRole
    let code: String
    let expiresAt: Date
    let createdAt: Date?

    init(invite: ProjectInvite) {
        self.id = invite.id!
        self.email = invite.email
        self.role = invite.role
        self.code = invite.token
        self.expiresAt = invite.expiresAt
        self.createdAt = invite.createdAt
    }
}

struct AcceptInviteDTO: Content {
    let code: String
}

struct InvitePreviewDTO: Content {
    let projectName: String
    let projectDescription: String?
    let invitedByName: String
    let role: ProjectRole
    let expiresAt: Date
    let emailMatches: Bool
    let inviteEmail: String
}

struct AcceptInviteResponseDTO: Content {
    let projectId: UUID
    let projectName: String
    let role: ProjectRole
}
