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
            memberCount: project.members.count,
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
            memberCount: project.members.count,
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
            memberCount: project.members.count,
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
            memberCount: project.members.count,
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
            memberCount: project.members.count,
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

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count,
            ownerEmail: project.owner.email
        )
    }

    // MARK: - Status Settings

    @Sendable
    func updateAllowedStatuses(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
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
            memberCount: project.members.count,
            ownerEmail: project.owner.email
        )
    }

    // MARK: - GitHub Integration

    @Sendable
    func updateGitHubSettings(req: Request) async throws -> ProjectResponseDTO {
        let user = try req.auth.require(User.self)
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

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count,
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

        try await project.save(on: req.db)

        try await project.$feedbacks.load(on: req.db)
        try await project.$members.load(on: req.db)
        try await project.$owner.load(on: req.db)

        return ProjectResponseDTO(
            project: project,
            feedbackCount: project.feedbacks.count,
            memberCount: project.members.count,
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
