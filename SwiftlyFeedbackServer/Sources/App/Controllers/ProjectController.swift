import Vapor
import Fluent

struct ProjectController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let projects = routes.grouped("projects")

        // All project routes require authentication
        let protected = projects.grouped(UserToken.authenticator(), User.guardMiddleware())

        protected.get(use: index)
        protected.post(use: create)
        protected.get(":projectId", use: show)
        protected.patch(":projectId", use: update)
        protected.delete(":projectId", use: delete)

        // Archive management
        protected.post(":projectId", "archive", use: archive)
        protected.post(":projectId", "unarchive", use: unarchive)

        // Regenerate API key
        protected.post(":projectId", "regenerate-key", use: regenerateApiKey)

        // Member management
        protected.get(":projectId", "members", use: listMembers)
        protected.post(":projectId", "members", use: addMember)
        protected.patch(":projectId", "members", ":memberId", use: updateMemberRole)
        protected.delete(":projectId", "members", ":memberId", use: removeMember)

        // Slack settings
        protected.patch(":projectId", "slack", use: updateSlackSettings)

        // Status settings
        protected.patch(":projectId", "statuses", use: updateAllowedStatuses)

        // GitHub integration
        protected.patch(":projectId", "github", use: updateGitHubSettings)
        protected.post(":projectId", "github", "issue", use: createGitHubIssue)
        protected.post(":projectId", "github", "issues", use: bulkCreateGitHubIssues)

        // ClickUp integration
        protected.patch(":projectId", "clickup", use: updateClickUpSettings)
        protected.post(":projectId", "clickup", "task", use: createClickUpTask)
        protected.post(":projectId", "clickup", "tasks", use: bulkCreateClickUpTasks)
        protected.get(":projectId", "clickup", "workspaces", use: getClickUpWorkspaces)
        protected.get(":projectId", "clickup", "spaces", ":workspaceId", use: getClickUpSpaces)
        protected.get(":projectId", "clickup", "folders", ":spaceId", use: getClickUpFolders)
        protected.get(":projectId", "clickup", "lists", ":folderId", use: getClickUpLists)
        protected.get(":projectId", "clickup", "folderless-lists", ":spaceId", use: getClickUpFolderlessLists)
        protected.get(":projectId", "clickup", "custom-fields", use: getClickUpCustomFields)

        // Notion integration
        protected.patch(":projectId", "notion", use: updateNotionSettings)
        protected.post(":projectId", "notion", "page", use: createNotionPage)
        protected.post(":projectId", "notion", "pages", use: bulkCreateNotionPages)
        protected.get(":projectId", "notion", "databases", use: getNotionDatabases)
        protected.get(":projectId", "notion", "database", ":databaseId", "properties", use: getNotionDatabaseProperties)

        // Monday.com integration
        protected.patch(":projectId", "monday", use: updateMondaySettings)
        protected.post(":projectId", "monday", "item", use: createMondayItem)
        protected.post(":projectId", "monday", "items", use: bulkCreateMondayItems)
        protected.get(":projectId", "monday", "boards", use: getMondayBoards)
        protected.get(":projectId", "monday", "boards", ":boardId", "groups", use: getMondayGroups)
        protected.get(":projectId", "monday", "boards", ":boardId", "columns", use: getMondayColumns)

        // Linear integration
        protected.patch(":projectId", "linear", use: updateLinearSettings)
        protected.post(":projectId", "linear", "issue", use: createLinearIssue)
        protected.post(":projectId", "linear", "issues", use: bulkCreateLinearIssues)
        protected.get(":projectId", "linear", "teams", use: getLinearTeams)
        protected.get(":projectId", "linear", "projects", ":teamId", use: getLinearProjects)
        protected.get(":projectId", "linear", "states", ":teamId", use: getLinearWorkflowStates)
        protected.get(":projectId", "linear", "labels", ":teamId", use: getLinearLabels)

        // Trello integration
        protected.patch(":projectId", "trello", use: updateTrelloSettings)
        protected.post(":projectId", "trello", "card", use: createTrelloCard)
        protected.post(":projectId", "trello", "cards", use: bulkCreateTrelloCards)
        protected.get(":projectId", "trello", "boards", use: getTrelloBoards)
        protected.get(":projectId", "trello", "boards", ":boardId", "lists", use: getTrelloLists)

        // Invite management
        protected.get(":projectId", "invites", use: listInvites)
        protected.delete(":projectId", "invites", ":inviteId", use: cancelInvite)
        protected.post(":projectId", "invites", ":inviteId", "resend", use: resendInvite)

        // Accept invite (user-facing, not project-specific)
        let invites = routes.grouped("invites")
        let protectedInvites = invites.grouped(UserToken.authenticator(), User.guardMiddleware())
        protectedInvites.post("accept", use: acceptInvite)
        protectedInvites.get("preview", ":code", use: previewInvite)
    }

    // MARK: - Project CRUD

    @Sendable
    func index(req: Request) async throws -> [ProjectListItemDTO] {
        let user = try req.auth.require(User.self)
        let userId = try user.requireID()

        // Get owned projects
        let ownedProjects = try await Project.query(on: req.db)
            .filter(\.$owner.$id == userId)
            .with(\.$feedbacks)
            .all()

        // Get projects where user is a member
        let memberships = try await ProjectMember.query(on: req.db)
            .filter(\.$user.$id == userId)
            .with(\.$project) { project in
                project.with(\.$feedbacks)
            }
            .all()

        var result: [ProjectListItemDTO] = []

        // Add owned projects
        for project in ownedProjects {
            result.append(ProjectListItemDTO(
                id: project.id!,
                name: project.name,
                description: project.description,
                isArchived: project.isArchived,
                isOwner: true,
                role: nil,
                colorIndex: project.colorIndex,
                feedbackCount: project.feedbacks.count,
                createdAt: project.createdAt
            ))
        }

        // Add member projects (avoiding duplicates)
        for membership in memberships {
            let project = membership.project
            if !result.contains(where: { $0.id == project.id }) {
                result.append(ProjectListItemDTO(
                    id: project.id!,
                    name: project.name,
                    description: project.description,
                    isArchived: project.isArchived,
                    isOwner: false,
                    role: membership.role,
                    colorIndex: project.colorIndex,
                    feedbackCount: project.feedbacks.count,
                    createdAt: project.createdAt
                ))
            }
        }

        return result.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    @Sendable
    func create(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
        try CreateProjectDTO.validate(content: req)
        let dto = try req.content.decode(CreateProjectDTO.self)

        // Check subscription project limit
        let currentProjectCount = try await Project.query(on: req.db)
            .filter(\.$owner.$id == user.requireID())
            .count()

        if let maxProjects = user.subscriptionTier.maxProjects, currentProjectCount >= maxProjects {
            throw Abort(.paymentRequired, reason: "Project limit reached. Upgrade to Pro for more projects. Current: \(currentProjectCount)/\(maxProjects)")
        }

        let apiKey = generateApiKey()
        let colorIndex = Int.random(in: 0..<8)
        let project = Project(
            name: dto.name,
            apiKey: apiKey,
            description: dto.description,
            ownerId: try user.requireID(),
            colorIndex: colorIndex
        )

        try await project.save(on: req.db)
        return ProjectResponseDTO(project: project, ownerEmail: user.email)
    }

    @Sendable
    func show(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectWithAccess(req: req, user: user)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func update(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        try UpdateProjectDTO.validate(content: req)
        let dto = try req.content.decode(UpdateProjectDTO.self)

        if let name = dto.name {
            project.name = name
        }
        if let description = dto.description {
            project.description = description
        }
        if let colorIndex = dto.colorIndex {
            project.colorIndex = colorIndex
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwner(req: req, user: user)

        try await project.delete(on: req.db)
        return .noContent
    }

    // MARK: - Archive Management

    @Sendable
    func archive(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwner(req: req, user: user)

        if project.isArchived {
            throw Abort(.badRequest, reason: "Project is already archived")
        }

        project.isArchived = true
        project.archivedAt = Date()
        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func unarchive(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwner(req: req, user: user)

        if !project.isArchived {
            throw Abort(.badRequest, reason: "Project is not archived")
        }

        project.isArchived = false
        project.archivedAt = nil
        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func regenerateApiKey(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwner(req: req, user: user)

        project.apiKey = generateApiKey()
        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    // MARK: - Member Management

    @Sendable
    func listMembers(req: Request) async throws -> [ProjectMember.Public] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectWithAccess(req: req, user: user)

        let members = try await ProjectMember.query(on: req.db)
            .filter(\.$project.$id == project.requireID())
            .with(\.$user)
            .all()

        return try members.map { try ProjectMember.Public(member: $0, user: $0.user) }
    }

    @Sendable
    func addMember(req: Request) async throws -> Response {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        // Load project owner to check their tier (not the logged-in user's tier)
        try await project.$owner.load(on: req.db)
        guard project.owner.subscriptionTier.meetsRequirement(.team) else {
            throw Abort(.paymentRequired, reason: "Project owner needs Team subscription to invite members")
        }

        try AddMemberDTO.validate(content: req)
        let dto = try req.content.decode(AddMemberDTO.self)
        let normalizedEmail = dto.email.lowercased()

        // Find user by email
        if let memberUser = try await User.query(on: req.db)
            .filter(\.$email == normalizedEmail)
            .first() {
            // User exists - add them directly
            // Check if user is already owner
            if project.$owner.id == memberUser.id {
                throw Abort(.conflict, reason: "User is the owner of this project")
            }

            // Check if already a member
            let existingMember = try await ProjectMember.query(on: req.db)
                .filter(\.$project.$id == project.requireID())
                .filter(\.$user.$id == memberUser.requireID())
                .first()

            if existingMember != nil {
                throw Abort(.conflict, reason: "User is already a member of this project")
            }

            let member = ProjectMember(
                projectId: try project.requireID(),
                userId: try memberUser.requireID(),
                role: dto.role
            )

            try await member.save(on: req.db)
            let publicMember = try ProjectMember.Public(member: member, user: memberUser)

            let response = Response(status: .created)
            try response.content.encode(AddMemberResponse(member: publicMember, inviteSent: false))
            return response
        } else {
            // User doesn't exist - send invite
            let projectId = try project.requireID()
            let userId = try user.requireID()

            // Check for existing pending invite
            let existingInvite = try await ProjectInvite.query(on: req.db)
                .filter(\.$project.$id == projectId)
                .filter(\.$email == normalizedEmail)
                .filter(\.$acceptedAt == nil)
                .first()

            if let existingInvite = existingInvite {
                if !existingInvite.isExpired {
                    throw Abort(.conflict, reason: "An invitation has already been sent to this email")
                }
                // Delete expired invite
                try await existingInvite.delete(on: req.db)
            }

            // Create new invite
            let invite = ProjectInvite(
                projectId: projectId,
                invitedById: userId,
                email: normalizedEmail,
                role: dto.role
            )

            try await invite.save(on: req.db)

            // Send email
            try await req.emailService.sendProjectInvite(
                to: normalizedEmail,
                inviterName: user.name,
                projectName: project.name,
                inviteCode: invite.token,
                role: dto.role
            )

            let response = Response(status: .created)
            try response.content.encode(AddMemberResponse(invite: invite, inviteSent: true))
            return response
        }
    }

    @Sendable
    func updateMemberRole(req: Request) async throws -> ProjectMember.Public {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let memberId = req.parameters.get("memberId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member ID")
        }

        let dto = try req.content.decode(UpdateMemberRoleDTO.self)

        guard let member = try await ProjectMember.query(on: req.db)
            .filter(\.$id == memberId)
            .filter(\.$project.$id == project.requireID())
            .with(\.$user)
            .first() else {
            throw Abort(.notFound, reason: "Member not found")
        }

        member.role = dto.role
        try await member.save(on: req.db)

        return try ProjectMember.Public(member: member, user: member.user)
    }

    @Sendable
    func removeMember(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let memberId = req.parameters.get("memberId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid member ID")
        }

        guard let member = try await ProjectMember.query(on: req.db)
            .filter(\.$id == memberId)
            .filter(\.$project.$id == project.requireID())
            .first() else {
            throw Abort(.notFound, reason: "Member not found")
        }

        try await member.delete(on: req.db)
        return .noContent
    }

    // MARK: - Invite Management

    @Sendable
    func listInvites(req: Request) async throws -> [ProjectInviteDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectWithAccess(req: req, user: user)

        let invites = try await ProjectInvite.query(on: req.db)
            .filter(\.$project.$id == project.requireID())
            .filter(\.$acceptedAt == nil)
            .sort(\.$createdAt, .descending)
            .all()

        return invites.map { ProjectInviteDTO(invite: $0) }
    }

    @Sendable
    func cancelInvite(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let inviteId = req.parameters.get("inviteId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid invite ID")
        }

        guard let invite = try await ProjectInvite.query(on: req.db)
            .filter(\.$id == inviteId)
            .filter(\.$project.$id == project.requireID())
            .first() else {
            throw Abort(.notFound, reason: "Invite not found")
        }

        try await invite.delete(on: req.db)
        return .noContent
    }

    @Sendable
    func resendInvite(req: Request) async throws -> ProjectInviteDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let inviteId = req.parameters.get("inviteId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid invite ID")
        }

        guard let invite = try await ProjectInvite.query(on: req.db)
            .filter(\.$id == inviteId)
            .filter(\.$project.$id == project.requireID())
            .filter(\.$acceptedAt == nil)
            .first() else {
            throw Abort(.notFound, reason: "Invite not found")
        }

        // Always regenerate code and reset expiration when resending
        invite.token = ProjectInvite.generateInviteCode()
        invite.expiresAt = Date().addingTimeInterval(7 * 24 * 60 * 60)
        try await invite.save(on: req.db)

        // Resend email
        try await req.emailService.sendProjectInvite(
            to: invite.email,
            inviterName: user.name,
            projectName: project.name,
            inviteCode: invite.token,
            role: invite.role
        )

        return ProjectInviteDTO(invite: invite)
    }

    @Sendable
    func previewInvite(req: Request) async throws -> InvitePreviewDTO {
        let user = try req.auth.require(User.self)

        guard let code = req.parameters.get("code") else {
            throw Abort(.badRequest, reason: "Invite code is required")
        }

        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard let invite = try await ProjectInvite.query(on: req.db)
            .filter(\.$token == normalizedCode)
            .filter(\.$acceptedAt == nil)
            .with(\.$project)
            .with(\.$invitedBy)
            .first() else {
            throw Abort(.notFound, reason: "Invalid or expired invite code")
        }

        if invite.isExpired {
            throw Abort(.gone, reason: "This invite has expired")
        }

        // Check if the invite email matches the user's email
        let emailMatches = invite.email == user.email.lowercased()

        return InvitePreviewDTO(
            projectName: invite.project.name,
            projectDescription: invite.project.description,
            invitedByName: invite.invitedBy.name,
            role: invite.role,
            expiresAt: invite.expiresAt,
            emailMatches: emailMatches,
            inviteEmail: invite.email
        )
    }

    @Sendable
    func acceptInvite(req: Request) async throws -> AcceptInviteResponseDTO {
        let user = try req.auth.require(User.self)

        // Check invitee has Team tier
        guard user.subscriptionTier.meetsRequirement(.team) else {
            throw Abort(.paymentRequired, reason: "You need a Team subscription to join projects as a member")
        }

        let dto = try req.content.decode(AcceptInviteDTO.self)

        let normalizedCode = dto.code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard let invite = try await ProjectInvite.query(on: req.db)
            .filter(\.$token == normalizedCode)
            .filter(\.$acceptedAt == nil)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Invalid or expired invite code")
        }

        if invite.isExpired {
            throw Abort(.gone, reason: "This invite has expired")
        }

        // Check if the invite email matches the user's email
        if invite.email != user.email.lowercased() {
            throw Abort(.forbidden, reason: "This invite was sent to a different email address")
        }

        // Check project owner still has Team tier
        try await invite.project.$owner.load(on: req.db)
        guard invite.project.owner.subscriptionTier.meetsRequirement(.team) else {
            throw Abort(.paymentRequired, reason: "The project owner's subscription no longer supports team members")
        }

        let userId = try user.requireID()
        let projectId = try invite.project.requireID()

        // Check if user is already the owner
        if invite.project.$owner.id == userId {
            throw Abort(.conflict, reason: "You are already the owner of this project")
        }

        // Check if user is already a member
        let existingMember = try await ProjectMember.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$user.$id == userId)
            .first()

        if existingMember != nil {
            throw Abort(.conflict, reason: "You are already a member of this project")
        }

        // Create membership
        let member = ProjectMember(
            projectId: projectId,
            userId: userId,
            role: invite.role
        )
        try await member.save(on: req.db)

        // Mark invite as accepted
        invite.acceptedAt = Date()
        try await invite.save(on: req.db)

        return AcceptInviteResponseDTO(
            projectId: projectId,
            projectName: invite.project.name,
            role: invite.role
        )
    }

    // MARK: - Slack Settings

    @Sendable
    func updateSlackSettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for integrations
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "Slack integration requires Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectSlackDTO.self)

        // Debug: Log what was decoded
        req.logger.info("Slack DTO decoded - webhookURL: \(dto.slackWebhookUrl ?? "nil"), notifyFeedback: \(dto.slackNotifyNewFeedback?.description ?? "nil"), notifyComments: \(dto.slackNotifyNewComments?.description ?? "nil"), notifyStatus: \(dto.slackNotifyStatusChanges?.description ?? "nil")")

        // Validate webhook URL format if provided
        if let webhookURL = dto.slackWebhookUrl, !webhookURL.isEmpty {
            guard webhookURL.hasPrefix("https://hooks.slack.com/") else {
                throw Abort(.badRequest, reason: "Invalid Slack webhook URL. It must start with https://hooks.slack.com/")
            }
        }

        if let webhookURL = dto.slackWebhookUrl {
            project.slackWebhookURL = webhookURL.isEmpty ? nil : webhookURL
        }
        if let notify = dto.slackNotifyNewFeedback {
            project.slackNotifyNewFeedback = notify
        }
        if let notify = dto.slackNotifyNewComments {
            project.slackNotifyNewComments = notify
        }
        if let notify = dto.slackNotifyStatusChanges {
            project.slackNotifyStatusChanges = notify
        }
        if let isActive = dto.slackIsActive {
            project.slackIsActive = isActive
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    // MARK: - Status Settings

    @Sendable
    func updateAllowedStatuses(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for configurable statuses
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "Configurable statuses require Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectStatusesDTO.self)

        // Validate that all provided statuses are valid FeedbackStatus values
        let validStatuses = FeedbackStatus.allCases.map { $0.rawValue }
        for status in dto.allowedStatuses {
            guard validStatuses.contains(status) else {
                throw Abort(.badRequest, reason: "Invalid status: \(status). Valid statuses are: \(validStatuses.joined(separator: ", "))")
            }
        }

        // Ensure at least pending and one completion status are included
        if !dto.allowedStatuses.contains("pending") {
            throw Abort(.badRequest, reason: "The 'pending' status must always be allowed")
        }

        project.allowedStatuses = dto.allowedStatuses

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    // MARK: - GitHub Integration

    @Sendable
    func updateGitHubSettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for integrations
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "GitHub integration requires Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectGitHubDTO.self)

        if let owner = dto.githubOwner {
            project.githubOwner = owner.isEmpty ? nil : owner.trimmingCharacters(in: .whitespaces)
        }
        if let repo = dto.githubRepo {
            project.githubRepo = repo.isEmpty ? nil : repo.trimmingCharacters(in: .whitespaces)
        }
        if let token = dto.githubToken {
            project.githubToken = token.isEmpty ? nil : token
        }
        if let labels = dto.githubDefaultLabels {
            project.githubDefaultLabels = labels.isEmpty ? nil : labels
        }
        if let syncStatus = dto.githubSyncStatus {
            project.githubSyncStatus = syncStatus
        }
        if let isActive = dto.githubIsActive {
            project.githubIsActive = isActive
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func createGitHubIssue(req: Request) async throws -> CreateGitHubIssueResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        // Validate GitHub is configured
        guard let owner = project.githubOwner,
              let repo = project.githubRepo,
              let token = project.githubToken else {
            throw Abort(.badRequest, reason: "GitHub integration not configured")
        }

        let dto = try req.content.decode(CreateGitHubIssueDTO.self)

        // Get feedback
        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == dto.feedbackId)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        // Check not already pushed
        if feedback.githubIssueURL != nil {
            throw Abort(.conflict, reason: "Feedback already has a GitHub issue")
        }

        // Build labels
        var labels = project.githubDefaultLabels ?? []
        if let additional = dto.additionalLabels {
            labels.append(contentsOf: additional)
        }
        // Add category as label
        labels.append(feedback.category.rawValue)

        // Calculate MRR for issue body
        let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        var totalMrr: Double = 0
        if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
            totalMrr += creatorMrr
        }
        for vote in feedback.votes {
            if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                totalMrr += voterMrr
            }
        }

        // Build issue body
        let body = req.githubService.buildIssueBody(
            feedback: feedback,
            projectName: project.name,
            voteCount: feedback.voteCount,
            mrr: totalMrr > 0 ? totalMrr : nil
        )

        // Create issue
        let response = try await req.githubService.createIssue(
            owner: owner,
            repo: repo,
            token: token,
            title: feedback.title,
            body: body,
            labels: labels.isEmpty ? nil : labels
        )

        // Update feedback with issue link
        feedback.githubIssueURL = response.htmlUrl
        feedback.githubIssueNumber = response.number
        try await feedback.save(on: req.db)

        return CreateGitHubIssueResponseDTO(
            feedbackId: feedback.id!,
            issueUrl: response.htmlUrl,
            issueNumber: response.number
        )
    }

    @Sendable
    func bulkCreateGitHubIssues(req: Request) async throws -> BulkCreateGitHubIssuesResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let owner = project.githubOwner,
              let repo = project.githubRepo,
              let token = project.githubToken else {
            throw Abort(.badRequest, reason: "GitHub integration not configured")
        }

        let dto = try req.content.decode(BulkCreateGitHubIssuesDTO.self)

        var created: [CreateGitHubIssueResponseDTO] = []
        var failed: [UUID] = []

        for feedbackId in dto.feedbackIds {
            do {
                guard let feedback = try await Feedback.query(on: req.db)
                    .filter(\.$id == feedbackId)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$votes)
                    .first() else {
                    failed.append(feedbackId)
                    continue
                }

                // Skip if already has issue
                if feedback.githubIssueURL != nil {
                    failed.append(feedbackId)
                    continue
                }

                var labels = project.githubDefaultLabels ?? []
                if let additional = dto.additionalLabels {
                    labels.append(contentsOf: additional)
                }
                labels.append(feedback.category.rawValue)

                // Calculate MRR
                let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
                let sdkUsers = try await SDKUser.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .filter(\.$userId ~~ Array(allUserIds))
                    .all()
                let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

                var totalMrr: Double = 0
                if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                    totalMrr += creatorMrr
                }
                for vote in feedback.votes {
                    if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                        totalMrr += voterMrr
                    }
                }

                let body = req.githubService.buildIssueBody(
                    feedback: feedback,
                    projectName: project.name,
                    voteCount: feedback.voteCount,
                    mrr: totalMrr > 0 ? totalMrr : nil
                )

                let response = try await req.githubService.createIssue(
                    owner: owner,
                    repo: repo,
                    token: token,
                    title: feedback.title,
                    body: body,
                    labels: labels.isEmpty ? nil : labels
                )

                feedback.githubIssueURL = response.htmlUrl
                feedback.githubIssueNumber = response.number
                try await feedback.save(on: req.db)

                created.append(CreateGitHubIssueResponseDTO(
                    feedbackId: feedback.id!,
                    issueUrl: response.htmlUrl,
                    issueNumber: response.number
                ))
            } catch {
                req.logger.error("Failed to create GitHub issue for \(feedbackId): \(error)")
                failed.append(feedbackId)
            }
        }

        return BulkCreateGitHubIssuesResponseDTO(created: created, failed: failed)
    }

    // MARK: - ClickUp Integration

    @Sendable
    func updateClickUpSettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for integrations
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "ClickUp integration requires Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectClickUpDTO.self)

        if let token = dto.clickupToken {
            project.clickupToken = token.isEmpty ? nil : token
        }
        if let listId = dto.clickupListId {
            project.clickupListId = listId.isEmpty ? nil : listId
        }
        if let workspaceName = dto.clickupWorkspaceName {
            project.clickupWorkspaceName = workspaceName.isEmpty ? nil : workspaceName
        }
        if let listName = dto.clickupListName {
            project.clickupListName = listName.isEmpty ? nil : listName
        }
        if let tags = dto.clickupDefaultTags {
            project.clickupDefaultTags = tags.isEmpty ? nil : tags
        }
        if let syncStatus = dto.clickupSyncStatus {
            project.clickupSyncStatus = syncStatus
        }
        if let syncComments = dto.clickupSyncComments {
            project.clickupSyncComments = syncComments
        }
        if let votesFieldId = dto.clickupVotesFieldId {
            project.clickupVotesFieldId = votesFieldId.isEmpty ? nil : votesFieldId
        }
        if let isActive = dto.clickupIsActive {
            project.clickupIsActive = isActive
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func createClickUpTask(req: Request) async throws -> CreateClickUpTaskResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken,
              let listId = project.clickupListId else {
            throw Abort(.badRequest, reason: "ClickUp integration not configured")
        }

        let dto = try req.content.decode(CreateClickUpTaskDTO.self)

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == dto.feedbackId)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        if feedback.clickupTaskURL != nil {
            throw Abort(.conflict, reason: "Feedback already has a ClickUp task")
        }

        // Build tags
        var tags = project.clickupDefaultTags ?? []
        if let additional = dto.additionalTags {
            tags.append(contentsOf: additional)
        }
        tags.append(feedback.category.rawValue)

        // Calculate MRR
        let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        var totalMrr: Double = 0
        if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
            totalMrr += creatorMrr
        }
        for vote in feedback.votes {
            if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                totalMrr += voterMrr
            }
        }

        let description = req.clickupService.buildTaskDescription(
            feedback: feedback,
            projectName: project.name,
            voteCount: feedback.voteCount,
            mrr: totalMrr > 0 ? totalMrr : nil
        )

        let response = try await req.clickupService.createTask(
            listId: listId,
            token: token,
            name: feedback.title,
            markdownDescription: description,
            tags: tags.isEmpty ? nil : tags
        )

        feedback.clickupTaskURL = response.url
        feedback.clickupTaskId = response.id
        try await feedback.save(on: req.db)

        // Sync initial vote count if votes field is configured
        if let votesFieldId = project.clickupVotesFieldId {
            Task {
                try? await req.clickupService.setCustomFieldValue(
                    taskId: response.id,
                    fieldId: votesFieldId,
                    token: token,
                    value: feedback.voteCount
                )
            }
        }

        return CreateClickUpTaskResponseDTO(
            feedbackId: feedback.id!,
            taskUrl: response.url,
            taskId: response.id
        )
    }

    @Sendable
    func bulkCreateClickUpTasks(req: Request) async throws -> BulkCreateClickUpTasksResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken,
              let listId = project.clickupListId else {
            throw Abort(.badRequest, reason: "ClickUp integration not configured")
        }

        let dto = try req.content.decode(BulkCreateClickUpTasksDTO.self)

        var created: [CreateClickUpTaskResponseDTO] = []
        var failed: [UUID] = []

        for feedbackId in dto.feedbackIds {
            do {
                guard let feedback = try await Feedback.query(on: req.db)
                    .filter(\.$id == feedbackId)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$votes)
                    .first() else {
                    failed.append(feedbackId)
                    continue
                }

                if feedback.clickupTaskURL != nil {
                    failed.append(feedbackId)
                    continue
                }

                var tags = project.clickupDefaultTags ?? []
                if let additional = dto.additionalTags {
                    tags.append(contentsOf: additional)
                }
                tags.append(feedback.category.rawValue)

                // Calculate MRR
                let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
                let sdkUsers = try await SDKUser.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .filter(\.$userId ~~ Array(allUserIds))
                    .all()
                let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

                var totalMrr: Double = 0
                if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                    totalMrr += creatorMrr
                }
                for vote in feedback.votes {
                    if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                        totalMrr += voterMrr
                    }
                }

                let description = req.clickupService.buildTaskDescription(
                    feedback: feedback,
                    projectName: project.name,
                    voteCount: feedback.voteCount,
                    mrr: totalMrr > 0 ? totalMrr : nil
                )

                let response = try await req.clickupService.createTask(
                    listId: listId,
                    token: token,
                    name: feedback.title,
                    markdownDescription: description,
                    tags: tags.isEmpty ? nil : tags
                )

                feedback.clickupTaskURL = response.url
                feedback.clickupTaskId = response.id
                try await feedback.save(on: req.db)

                created.append(CreateClickUpTaskResponseDTO(
                    feedbackId: feedback.id!,
                    taskUrl: response.url,
                    taskId: response.id
                ))
            } catch {
                req.logger.error("Failed to create ClickUp task for \(feedbackId): \(error)")
                failed.append(feedbackId)
            }
        }

        return BulkCreateClickUpTasksResponseDTO(created: created, failed: failed)
    }

    @Sendable
    func getClickUpWorkspaces(req: Request) async throws -> [ClickUpWorkspaceDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken else {
            throw Abort(.badRequest, reason: "ClickUp token not configured")
        }

        let workspaces = try await req.clickupService.getWorkspaces(token: token)
        return workspaces.map { ClickUpWorkspaceDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func getClickUpSpaces(req: Request) async throws -> [ClickUpSpaceDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken else {
            throw Abort(.badRequest, reason: "ClickUp token not configured")
        }

        guard let workspaceId = req.parameters.get("workspaceId") else {
            throw Abort(.badRequest, reason: "Workspace ID required")
        }

        let spaces = try await req.clickupService.getSpaces(workspaceId: workspaceId, token: token)
        return spaces.map { ClickUpSpaceDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func getClickUpFolders(req: Request) async throws -> [ClickUpFolderDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken else {
            throw Abort(.badRequest, reason: "ClickUp token not configured")
        }

        guard let spaceId = req.parameters.get("spaceId") else {
            throw Abort(.badRequest, reason: "Space ID required")
        }

        let folders = try await req.clickupService.getFolders(spaceId: spaceId, token: token)
        return folders.map { ClickUpFolderDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func getClickUpLists(req: Request) async throws -> [ClickUpListDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken else {
            throw Abort(.badRequest, reason: "ClickUp token not configured")
        }

        guard let folderId = req.parameters.get("folderId") else {
            throw Abort(.badRequest, reason: "Folder ID required")
        }

        let lists = try await req.clickupService.getLists(folderId: folderId, token: token)
        return lists.map { ClickUpListDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func getClickUpFolderlessLists(req: Request) async throws -> [ClickUpListDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken else {
            throw Abort(.badRequest, reason: "ClickUp token not configured")
        }

        guard let spaceId = req.parameters.get("spaceId") else {
            throw Abort(.badRequest, reason: "Space ID required")
        }

        let lists = try await req.clickupService.getFolderlessLists(spaceId: spaceId, token: token)
        return lists.map { ClickUpListDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func getClickUpCustomFields(req: Request) async throws -> [ClickUpCustomFieldDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.clickupToken,
              let listId = project.clickupListId else {
            throw Abort(.badRequest, reason: "ClickUp integration not configured")
        }

        let fields = try await req.clickupService.getListCustomFields(listId: listId, token: token)
        // Filter to only return number fields (suitable for vote count)
        return fields
            .filter { $0.type == "number" }
            .map { ClickUpCustomFieldDTO(id: $0.id, name: $0.name, type: $0.type) }
    }

    // MARK: - Notion Integration

    @Sendable
    func updateNotionSettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for integrations
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "Notion integration requires Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectNotionDTO.self)

        if let token = dto.notionToken {
            project.notionToken = token.isEmpty ? nil : token
        }
        if let databaseId = dto.notionDatabaseId {
            project.notionDatabaseId = databaseId.isEmpty ? nil : databaseId
        }
        if let databaseName = dto.notionDatabaseName {
            project.notionDatabaseName = databaseName.isEmpty ? nil : databaseName
        }
        if let syncStatus = dto.notionSyncStatus {
            project.notionSyncStatus = syncStatus
        }
        if let syncComments = dto.notionSyncComments {
            project.notionSyncComments = syncComments
        }
        if let statusProperty = dto.notionStatusProperty {
            project.notionStatusProperty = statusProperty.isEmpty ? nil : statusProperty
        }
        if let votesProperty = dto.notionVotesProperty {
            project.notionVotesProperty = votesProperty.isEmpty ? nil : votesProperty
        }
        if let isActive = dto.notionIsActive {
            project.notionIsActive = isActive
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func createNotionPage(req: Request) async throws -> CreateNotionPageResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.notionToken,
              let databaseId = project.notionDatabaseId else {
            throw Abort(.badRequest, reason: "Notion integration not configured")
        }

        let dto = try req.content.decode(CreateNotionPageDTO.self)

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == dto.feedbackId)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        if feedback.notionPageURL != nil {
            throw Abort(.conflict, reason: "Feedback already has a Notion page")
        }

        // Calculate MRR
        let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        var totalMrr: Double = 0
        if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
            totalMrr += creatorMrr
        }
        for vote in feedback.votes {
            if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                totalMrr += voterMrr
            }
        }

        let content = req.notionService.buildPageContent(
            feedback: feedback,
            projectName: project.name,
            voteCount: feedback.voteCount,
            mrr: totalMrr > 0 ? totalMrr : nil
        )

        let properties = req.notionService.buildPageProperties(
            feedback: feedback,
            voteCount: feedback.voteCount,
            mrr: totalMrr > 0 ? totalMrr : nil,
            statusProperty: project.notionStatusProperty,
            votesProperty: project.notionVotesProperty
        )

        let response = try await req.notionService.createPage(
            databaseId: databaseId,
            token: token,
            title: feedback.title,
            properties: properties,
            content: content
        )

        feedback.notionPageURL = response.url
        feedback.notionPageId = response.id
        try await feedback.save(on: req.db)

        return CreateNotionPageResponseDTO(
            feedbackId: feedback.id!,
            pageUrl: response.url,
            pageId: response.id
        )
    }

    @Sendable
    func bulkCreateNotionPages(req: Request) async throws -> BulkCreateNotionPagesResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.notionToken,
              let databaseId = project.notionDatabaseId else {
            throw Abort(.badRequest, reason: "Notion integration not configured")
        }

        let dto = try req.content.decode(BulkCreateNotionPagesDTO.self)

        var created: [CreateNotionPageResponseDTO] = []
        var failed: [UUID] = []

        for feedbackId in dto.feedbackIds {
            do {
                guard let feedback = try await Feedback.query(on: req.db)
                    .filter(\.$id == feedbackId)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$votes)
                    .first() else {
                    failed.append(feedbackId)
                    continue
                }

                if feedback.notionPageURL != nil {
                    failed.append(feedbackId)
                    continue
                }

                // Calculate MRR
                let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
                let sdkUsers = try await SDKUser.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .filter(\.$userId ~~ Array(allUserIds))
                    .all()
                let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

                var totalMrr: Double = 0
                if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                    totalMrr += creatorMrr
                }
                for vote in feedback.votes {
                    if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                        totalMrr += voterMrr
                    }
                }

                let content = req.notionService.buildPageContent(
                    feedback: feedback,
                    projectName: project.name,
                    voteCount: feedback.voteCount,
                    mrr: totalMrr > 0 ? totalMrr : nil
                )

                let properties = req.notionService.buildPageProperties(
                    feedback: feedback,
                    voteCount: feedback.voteCount,
                    mrr: totalMrr > 0 ? totalMrr : nil,
                    statusProperty: project.notionStatusProperty,
                    votesProperty: project.notionVotesProperty
                )

                let response = try await req.notionService.createPage(
                    databaseId: databaseId,
                    token: token,
                    title: feedback.title,
                    properties: properties,
                    content: content
                )

                feedback.notionPageURL = response.url
                feedback.notionPageId = response.id
                try await feedback.save(on: req.db)

                created.append(CreateNotionPageResponseDTO(
                    feedbackId: feedback.id!,
                    pageUrl: response.url,
                    pageId: response.id
                ))
            } catch {
                req.logger.error("Failed to create Notion page for \(feedbackId): \(error)")
                failed.append(feedbackId)
            }
        }

        return BulkCreateNotionPagesResponseDTO(created: created, failed: failed)
    }

    @Sendable
    func getNotionDatabases(req: Request) async throws -> [NotionDatabaseDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.notionToken else {
            throw Abort(.badRequest, reason: "Notion token not configured")
        }

        let databases = try await req.notionService.searchDatabases(token: token)
        return databases.map { db in
            NotionDatabaseDTO(
                id: db.id,
                name: db.name,
                properties: db.properties.map { (name, prop) in
                    NotionPropertyDTO(id: prop.id, name: name, type: prop.type)
                }
            )
        }
    }

    @Sendable
    func getNotionDatabaseProperties(req: Request) async throws -> NotionDatabaseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.notionToken else {
            throw Abort(.badRequest, reason: "Notion token not configured")
        }

        guard let databaseId = req.parameters.get("databaseId") else {
            throw Abort(.badRequest, reason: "Database ID required")
        }

        let database = try await req.notionService.getDatabase(databaseId: databaseId, token: token)
        return NotionDatabaseDTO(
            id: database.id,
            name: database.name,
            properties: database.properties.map { (name, prop) in
                NotionPropertyDTO(id: prop.id, name: name, type: prop.type)
            }
        )
    }

    // MARK: - Monday.com Integration

    @Sendable
    func updateMondaySettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for integrations
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "Monday.com integration requires Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectMondayDTO.self)

        if let token = dto.mondayToken {
            project.mondayToken = token.isEmpty ? nil : token
        }
        if let boardId = dto.mondayBoardId {
            project.mondayBoardId = boardId.isEmpty ? nil : boardId
        }
        if let boardName = dto.mondayBoardName {
            project.mondayBoardName = boardName.isEmpty ? nil : boardName
        }
        if let groupId = dto.mondayGroupId {
            project.mondayGroupId = groupId.isEmpty ? nil : groupId
        }
        if let groupName = dto.mondayGroupName {
            project.mondayGroupName = groupName.isEmpty ? nil : groupName
        }
        if let syncStatus = dto.mondaySyncStatus {
            project.mondaySyncStatus = syncStatus
        }
        if let syncComments = dto.mondaySyncComments {
            project.mondaySyncComments = syncComments
        }
        if let statusColumnId = dto.mondayStatusColumnId {
            project.mondayStatusColumnId = statusColumnId.isEmpty ? nil : statusColumnId
        }
        if let votesColumnId = dto.mondayVotesColumnId {
            project.mondayVotesColumnId = votesColumnId.isEmpty ? nil : votesColumnId
        }
        if let isActive = dto.mondayIsActive {
            project.mondayIsActive = isActive
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func createMondayItem(req: Request) async throws -> CreateMondayItemResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.mondayToken,
              let boardId = project.mondayBoardId else {
            throw Abort(.badRequest, reason: "Monday.com integration not configured")
        }

        let dto = try req.content.decode(CreateMondayItemDTO.self)

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == dto.feedbackId)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        if feedback.mondayItemURL != nil {
            throw Abort(.conflict, reason: "Feedback already has a Monday.com item")
        }

        // Calculate MRR
        let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        var totalMrr: Double = 0
        if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
            totalMrr += creatorMrr
        }
        for vote in feedback.votes {
            if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                totalMrr += voterMrr
            }
        }

        // Create the item
        let item = try await req.mondayService.createItem(
            boardId: boardId,
            groupId: project.mondayGroupId,
            token: token,
            name: feedback.title
        )

        // Build URL
        let itemUrl = req.mondayService.buildItemURL(boardId: boardId, itemId: item.id)

        // Save link to feedback
        feedback.mondayItemURL = itemUrl
        feedback.mondayItemId = item.id
        try await feedback.save(on: req.db)

        // Create initial update (comment) with description
        let description = req.mondayService.buildItemDescription(
            feedback: feedback,
            projectName: project.name,
            voteCount: feedback.voteCount,
            mrr: totalMrr > 0 ? totalMrr : nil
        )

        Task {
            _ = try? await req.mondayService.createUpdate(
                itemId: item.id,
                token: token,
                body: description
            )

            // Sync initial vote count if votes column is configured
            if let votesColumnId = project.mondayVotesColumnId {
                try? await req.mondayService.updateItemNumber(
                    boardId: boardId,
                    itemId: item.id,
                    columnId: votesColumnId,
                    token: token,
                    value: feedback.voteCount
                )
            }

            // Set initial status if status column is configured
            if let statusColumnId = project.mondayStatusColumnId {
                try? await req.mondayService.updateItemStatus(
                    boardId: boardId,
                    itemId: item.id,
                    columnId: statusColumnId,
                    token: token,
                    status: feedback.status.mondayStatusName
                )
            }
        }

        return CreateMondayItemResponseDTO(
            feedbackId: feedback.id!,
            itemUrl: itemUrl,
            itemId: item.id
        )
    }

    @Sendable
    func bulkCreateMondayItems(req: Request) async throws -> BulkCreateMondayItemsResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.mondayToken,
              let boardId = project.mondayBoardId else {
            throw Abort(.badRequest, reason: "Monday.com integration not configured")
        }

        let dto = try req.content.decode(BulkCreateMondayItemsDTO.self)

        var created: [CreateMondayItemResponseDTO] = []
        var failed: [UUID] = []

        for feedbackId in dto.feedbackIds {
            do {
                guard let feedback = try await Feedback.query(on: req.db)
                    .filter(\.$id == feedbackId)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$votes)
                    .first() else {
                    failed.append(feedbackId)
                    continue
                }

                if feedback.mondayItemURL != nil {
                    failed.append(feedbackId)
                    continue
                }

                // Calculate MRR
                let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
                let sdkUsers = try await SDKUser.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .filter(\.$userId ~~ Array(allUserIds))
                    .all()
                let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

                var totalMrr: Double = 0
                if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                    totalMrr += creatorMrr
                }
                for vote in feedback.votes {
                    if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                        totalMrr += voterMrr
                    }
                }

                let item = try await req.mondayService.createItem(
                    boardId: boardId,
                    groupId: project.mondayGroupId,
                    token: token,
                    name: feedback.title
                )

                let itemUrl = req.mondayService.buildItemURL(boardId: boardId, itemId: item.id)

                feedback.mondayItemURL = itemUrl
                feedback.mondayItemId = item.id
                try await feedback.save(on: req.db)

                // Create update with description (fire and forget)
                let description = req.mondayService.buildItemDescription(
                    feedback: feedback,
                    projectName: project.name,
                    voteCount: feedback.voteCount,
                    mrr: totalMrr > 0 ? totalMrr : nil
                )

                Task {
                    _ = try? await req.mondayService.createUpdate(
                        itemId: item.id,
                        token: token,
                        body: description
                    )
                }

                created.append(CreateMondayItemResponseDTO(
                    feedbackId: feedback.id!,
                    itemUrl: itemUrl,
                    itemId: item.id
                ))
            } catch {
                req.logger.error("Failed to create Monday.com item for \(feedbackId): \(error)")
                failed.append(feedbackId)
            }
        }

        return BulkCreateMondayItemsResponseDTO(created: created, failed: failed)
    }

    @Sendable
    func getMondayBoards(req: Request) async throws -> [MondayBoardDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.mondayToken else {
            throw Abort(.badRequest, reason: "Monday.com token not configured")
        }

        let boards = try await req.mondayService.getBoards(token: token)
        return boards.map { MondayBoardDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func getMondayGroups(req: Request) async throws -> [MondayGroupDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.mondayToken else {
            throw Abort(.badRequest, reason: "Monday.com token not configured")
        }

        guard let boardId = req.parameters.get("boardId") else {
            throw Abort(.badRequest, reason: "Board ID required")
        }

        let groups = try await req.mondayService.getGroups(boardId: boardId, token: token)
        return groups.map { MondayGroupDTO(id: $0.id, title: $0.title) }
    }

    @Sendable
    func getMondayColumns(req: Request) async throws -> [MondayColumnDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.mondayToken else {
            throw Abort(.badRequest, reason: "Monday.com token not configured")
        }

        guard let boardId = req.parameters.get("boardId") else {
            throw Abort(.badRequest, reason: "Board ID required")
        }

        let columns = try await req.mondayService.getColumns(boardId: boardId, token: token)
        return columns.map { MondayColumnDTO(id: $0.id, title: $0.title, type: $0.type) }
    }

    // MARK: - Linear Integration

    @Sendable
    func updateLinearSettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for integrations
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "Linear integration requires Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectLinearDTO.self)

        if let token = dto.linearToken {
            project.linearToken = token.isEmpty ? nil : token
        }
        if let teamId = dto.linearTeamId {
            project.linearTeamId = teamId.isEmpty ? nil : teamId
        }
        if let teamName = dto.linearTeamName {
            project.linearTeamName = teamName.isEmpty ? nil : teamName
        }
        if let projectId = dto.linearProjectId {
            project.linearProjectId = projectId.isEmpty ? nil : projectId
        }
        if let projectName = dto.linearProjectName {
            project.linearProjectName = projectName.isEmpty ? nil : projectName
        }
        if let labelIds = dto.linearDefaultLabelIds {
            project.linearDefaultLabelIds = labelIds.isEmpty ? nil : labelIds
        }
        if let syncStatus = dto.linearSyncStatus {
            project.linearSyncStatus = syncStatus
        }
        if let syncComments = dto.linearSyncComments {
            project.linearSyncComments = syncComments
        }
        if let isActive = dto.linearIsActive {
            project.linearIsActive = isActive
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func createLinearIssue(req: Request) async throws -> CreateLinearIssueResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.linearToken,
              let teamId = project.linearTeamId else {
            throw Abort(.badRequest, reason: "Linear integration not configured")
        }

        let dto = try req.content.decode(CreateLinearIssueDTO.self)

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == dto.feedbackId)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        if feedback.linearIssueURL != nil {
            throw Abort(.conflict, reason: "Feedback already has a Linear issue")
        }

        // Build label IDs
        var labelIds = project.linearDefaultLabelIds ?? []
        if let additional = dto.additionalLabelIds {
            labelIds.append(contentsOf: additional)
        }

        // Calculate MRR
        let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        var totalMrr: Double = 0
        if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
            totalMrr += creatorMrr
        }
        for vote in feedback.votes {
            if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                totalMrr += voterMrr
            }
        }

        let description = req.linearService.buildIssueDescription(
            feedback: feedback,
            projectName: project.name,
            voteCount: feedback.voteCount,
            mrr: totalMrr > 0 ? totalMrr : nil
        )

        let issue = try await req.linearService.createIssue(
            teamId: teamId,
            projectId: project.linearProjectId,
            title: feedback.title,
            description: description,
            labelIds: labelIds.isEmpty ? nil : labelIds,
            token: token
        )

        feedback.linearIssueURL = issue.url
        feedback.linearIssueId = issue.id
        try await feedback.save(on: req.db)

        return CreateLinearIssueResponseDTO(
            feedbackId: feedback.id!,
            issueUrl: issue.url,
            issueId: issue.id,
            identifier: issue.identifier
        )
    }

    @Sendable
    func bulkCreateLinearIssues(req: Request) async throws -> BulkCreateLinearIssuesResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.linearToken,
              let teamId = project.linearTeamId else {
            throw Abort(.badRequest, reason: "Linear integration not configured")
        }

        let dto = try req.content.decode(BulkCreateLinearIssuesDTO.self)

        var created: [CreateLinearIssueResponseDTO] = []
        var failed: [UUID] = []

        for feedbackId in dto.feedbackIds {
            do {
                guard let feedback = try await Feedback.query(on: req.db)
                    .filter(\.$id == feedbackId)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$votes)
                    .first() else {
                    failed.append(feedbackId)
                    continue
                }

                if feedback.linearIssueURL != nil {
                    failed.append(feedbackId)
                    continue
                }

                var labelIds = project.linearDefaultLabelIds ?? []
                if let additional = dto.additionalLabelIds {
                    labelIds.append(contentsOf: additional)
                }

                // Calculate MRR
                let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
                let sdkUsers = try await SDKUser.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .filter(\.$userId ~~ Array(allUserIds))
                    .all()
                let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

                var totalMrr: Double = 0
                if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                    totalMrr += creatorMrr
                }
                for vote in feedback.votes {
                    if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                        totalMrr += voterMrr
                    }
                }

                let description = req.linearService.buildIssueDescription(
                    feedback: feedback,
                    projectName: project.name,
                    voteCount: feedback.voteCount,
                    mrr: totalMrr > 0 ? totalMrr : nil
                )

                let issue = try await req.linearService.createIssue(
                    teamId: teamId,
                    projectId: project.linearProjectId,
                    title: feedback.title,
                    description: description,
                    labelIds: labelIds.isEmpty ? nil : labelIds,
                    token: token
                )

                feedback.linearIssueURL = issue.url
                feedback.linearIssueId = issue.id
                try await feedback.save(on: req.db)

                created.append(CreateLinearIssueResponseDTO(
                    feedbackId: feedback.id!,
                    issueUrl: issue.url,
                    issueId: issue.id,
                    identifier: issue.identifier
                ))
            } catch {
                req.logger.error("Failed to create Linear issue for \(feedbackId): \(error)")
                failed.append(feedbackId)
            }
        }

        return BulkCreateLinearIssuesResponseDTO(created: created, failed: failed)
    }

    @Sendable
    func getLinearTeams(req: Request) async throws -> [LinearTeamDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.linearToken else {
            throw Abort(.badRequest, reason: "Linear token not configured")
        }

        let teams = try await req.linearService.getTeams(token: token)
        return teams.map { LinearTeamDTO(id: $0.id, name: $0.name, key: $0.key) }
    }

    @Sendable
    func getLinearProjects(req: Request) async throws -> [LinearProjectDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.linearToken else {
            throw Abort(.badRequest, reason: "Linear token not configured")
        }

        guard let teamId = req.parameters.get("teamId") else {
            throw Abort(.badRequest, reason: "Team ID required")
        }

        let projects = try await req.linearService.getProjects(teamId: teamId, token: token)
        return projects.map { LinearProjectDTO(id: $0.id, name: $0.name, state: $0.state) }
    }

    @Sendable
    func getLinearWorkflowStates(req: Request) async throws -> [LinearWorkflowStateDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.linearToken else {
            throw Abort(.badRequest, reason: "Linear token not configured")
        }

        guard let teamId = req.parameters.get("teamId") else {
            throw Abort(.badRequest, reason: "Team ID required")
        }

        let states = try await req.linearService.getWorkflowStates(teamId: teamId, token: token)
        return states.map { LinearWorkflowStateDTO(id: $0.id, name: $0.name, type: $0.type, position: $0.position) }
    }

    @Sendable
    func getLinearLabels(req: Request) async throws -> [LinearLabelDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.linearToken else {
            throw Abort(.badRequest, reason: "Linear token not configured")
        }

        guard let teamId = req.parameters.get("teamId") else {
            throw Abort(.badRequest, reason: "Team ID required")
        }

        let labels = try await req.linearService.getLabels(teamId: teamId, token: token)
        return labels.map { LinearLabelDTO(id: $0.id, name: $0.name, color: $0.color) }
    }

    // MARK: - Trello Integration

    @Sendable
    func updateTrelloSettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)

        // Check Pro tier requirement for integrations
        guard user.subscriptionTier.meetsRequirement(.pro) else {
            throw Abort(.paymentRequired, reason: "Trello integration requires Pro subscription")
        }

        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        let dto = try req.content.decode(UpdateProjectTrelloDTO.self)

        if let token = dto.trelloToken {
            project.trelloToken = token.isEmpty ? nil : token
        }
        if let boardId = dto.trelloBoardId {
            project.trelloBoardId = boardId.isEmpty ? nil : boardId
        }
        if let boardName = dto.trelloBoardName {
            project.trelloBoardName = boardName.isEmpty ? nil : boardName
        }
        if let listId = dto.trelloListId {
            project.trelloListId = listId.isEmpty ? nil : listId
        }
        if let listName = dto.trelloListName {
            project.trelloListName = listName.isEmpty ? nil : listName
        }
        if let syncStatus = dto.trelloSyncStatus {
            project.trelloSyncStatus = syncStatus
        }
        if let syncComments = dto.trelloSyncComments {
            project.trelloSyncComments = syncComments
        }
        if let isActive = dto.trelloIsActive {
            project.trelloIsActive = isActive
        }

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count + 1,  // +1 for owner
            ownerEmail: project.owner.email
        )
    }

    @Sendable
    func createTrelloCard(req: Request) async throws -> CreateTrelloCardResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.trelloToken,
              let listId = project.trelloListId else {
            throw Abort(.badRequest, reason: "Trello integration not configured")
        }

        guard project.trelloIsActive else {
            throw Abort(.badRequest, reason: "Trello integration is not active")
        }

        let dto = try req.content.decode(CreateTrelloCardDTO.self)

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == dto.feedbackId)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        if feedback.trelloCardURL != nil {
            throw Abort(.conflict, reason: "Feedback already has a Trello card")
        }

        // Calculate MRR
        let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        var totalMrr: Double = 0
        if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
            totalMrr += creatorMrr
        }
        for vote in feedback.votes {
            if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                totalMrr += voterMrr
            }
        }

        let description = req.trelloService.buildCardDescription(
            feedback: feedback,
            projectName: project.name,
            voteCount: feedback.voteCount,
            mrr: totalMrr > 0 ? totalMrr : nil
        )

        let card = try await req.trelloService.createCard(
            token: token,
            listId: listId,
            name: feedback.title,
            description: description
        )

        feedback.trelloCardURL = card.url
        feedback.trelloCardId = card.id
        try await feedback.save(on: req.db)

        return CreateTrelloCardResponseDTO(
            feedbackId: feedback.id!,
            cardUrl: card.url,
            cardId: card.id
        )
    }

    @Sendable
    func bulkCreateTrelloCards(req: Request) async throws -> BulkCreateTrelloCardsResponseDTO {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.trelloToken,
              let listId = project.trelloListId else {
            throw Abort(.badRequest, reason: "Trello integration not configured")
        }

        guard project.trelloIsActive else {
            throw Abort(.badRequest, reason: "Trello integration is not active")
        }

        let dto = try req.content.decode(BulkCreateTrelloCardsDTO.self)

        var created: [CreateTrelloCardResponseDTO] = []
        var failed: [UUID] = []

        for feedbackId in dto.feedbackIds {
            do {
                guard let feedback = try await Feedback.query(on: req.db)
                    .filter(\.$id == feedbackId)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$votes)
                    .first() else {
                    failed.append(feedbackId)
                    continue
                }

                if feedback.trelloCardURL != nil {
                    failed.append(feedbackId)
                    continue
                }

                // Calculate MRR
                let allUserIds = Set([feedback.userId] + feedback.votes.map { $0.userId })
                let sdkUsers = try await SDKUser.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .filter(\.$userId ~~ Array(allUserIds))
                    .all()
                let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

                var totalMrr: Double = 0
                if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                    totalMrr += creatorMrr
                }
                for vote in feedback.votes {
                    if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                        totalMrr += voterMrr
                    }
                }

                let description = req.trelloService.buildCardDescription(
                    feedback: feedback,
                    projectName: project.name,
                    voteCount: feedback.voteCount,
                    mrr: totalMrr > 0 ? totalMrr : nil
                )

                let card = try await req.trelloService.createCard(
                    token: token,
                    listId: listId,
                    name: feedback.title,
                    description: description
                )

                feedback.trelloCardURL = card.url
                feedback.trelloCardId = card.id
                try await feedback.save(on: req.db)

                created.append(CreateTrelloCardResponseDTO(
                    feedbackId: feedback.id!,
                    cardUrl: card.url,
                    cardId: card.id
                ))
            } catch {
                req.logger.error("Failed to create Trello card for \(feedbackId): \(error)")
                failed.append(feedbackId)
            }
        }

        return BulkCreateTrelloCardsResponseDTO(created: created, failed: failed)
    }

    @Sendable
    func getTrelloBoards(req: Request) async throws -> [TrelloBoardDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.trelloToken else {
            throw Abort(.badRequest, reason: "Trello token not configured")
        }

        let boards = try await req.trelloService.getBoards(token: token)
        return boards.map { TrelloBoardDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func getTrelloLists(req: Request) async throws -> [TrelloListDTO] {
        let user = try req.auth.require(User.self)
        let project = try await getProjectAsOwnerOrAdmin(req: req, user: user)

        guard let token = project.trelloToken else {
            throw Abort(.badRequest, reason: "Trello token not configured")
        }

        guard let boardId = req.parameters.get("boardId") else {
            throw Abort(.badRequest, reason: "Board ID required")
        }

        let lists = try await req.trelloService.getLists(token: token, boardId: boardId)
        return lists.map { TrelloListDTO(id: $0.id, name: $0.name) }
    }

    // MARK: - Helpers

    private func getProjectWithAccess(req: Request, user: User) async throws -> Project {
        guard let projectId = req.parameters.get("projectId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await Project.find(projectId, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let userId = try user.requireID()
        guard try await project.userHasAccess(userId, on: req.db) else {
            throw Abort(.forbidden, reason: "You don't have access to this project")
        }

        return project
    }

    private func getProjectAsOwner(req: Request, user: User) async throws -> Project {
        guard let projectId = req.parameters.get("projectId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await Project.find(projectId, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let userId = try user.requireID()
        guard project.userIsOwner(userId) else {
            throw Abort(.forbidden, reason: "Only the project owner can perform this action")
        }

        return project
    }

    private func getProjectAsOwnerOrAdmin(req: Request, user: User) async throws -> Project {
        guard let projectId = req.parameters.get("projectId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await Project.find(projectId, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        let userId = try user.requireID()

        // Owner has full access
        if project.userIsOwner(userId) {
            return project
        }

        // Check if user is an admin member
        let membership = try await ProjectMember.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$user.$id == userId)
            .first()

        guard let membership = membership, membership.role == .admin else {
            throw Abort(.forbidden, reason: "Only the project owner or admin can perform this action")
        }

        return project
    }

    private func generateApiKey() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return "sf_" + String((0..<32).map { _ in chars.randomElement()! })
    }
}
