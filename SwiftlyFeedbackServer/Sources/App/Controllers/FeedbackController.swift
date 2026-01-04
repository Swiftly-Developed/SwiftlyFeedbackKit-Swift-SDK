import Vapor
import Fluent

struct FeedbackController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let feedbacks = routes.grouped("feedbacks")

        // Public API routes (for SDK) - require API key
        feedbacks.get(use: index)
        feedbacks.post(use: create)
        feedbacks.get(":feedbackId", use: show)

        // Admin routes - require authentication
        let protected = feedbacks.grouped(UserToken.authenticator(), User.guardMiddleware())
        protected.patch(":feedbackId", use: update)
        protected.delete(":feedbackId", use: delete)
    }

    /// Get the project from API key and validate it's not archived for write operations
    private func getProjectFromApiKey(req: Request, requireActive: Bool = false) async throws -> Project {
        guard let apiKey = req.headers.first(name: "X-API-Key") else {
            throw Abort(.unauthorized, reason: "API key required")
        }

        guard let project = try await Project.query(on: req.db)
            .filter(\.$apiKey == apiKey)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid API key")
        }

        if requireActive && project.isArchived {
            throw Abort(.forbidden, reason: "This project is archived and cannot receive new feedback. Contact the project owner to unarchive it.")
        }

        return project
    }

    @Sendable
    func index(req: Request) async throws -> [FeedbackResponseDTO] {
        // Reading feedback is allowed even for archived projects
        let project = try await getProjectFromApiKey(req: req, requireActive: false)

        let userId = req.headers.first(name: "X-User-Id")
        let statusFilter = req.query[String.self, at: "status"]
        let categoryFilter = req.query[String.self, at: "category"]

        var query = Feedback.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .with(\.$comments)

        if let status = statusFilter, let feedbackStatus = FeedbackStatus(rawValue: status) {
            query = query.filter(\.$status == feedbackStatus)
        }

        if let category = categoryFilter, let feedbackCategory = FeedbackCategory(rawValue: category) {
            query = query.filter(\.$category == feedbackCategory)
        }

        let feedbacks = try await query.sort(\.$voteCount, .descending).all()

        // Collect all user IDs (creators + voters) to fetch MRR data
        var allUserIds = Set<String>()
        for feedback in feedbacks {
            allUserIds.insert(feedback.userId)
            for vote in feedback.votes {
                allUserIds.insert(vote.userId)
            }
        }

        // Fetch SDK users to get MRR data
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        return feedbacks.map { feedback in
            let hasVoted = userId.map { uid in feedback.votes.contains { $0.userId == uid } } ?? false

            // Calculate total MRR: creator + all voters
            var totalMrr: Double = 0
            if let creatorMrr = mrrByUserId[feedback.userId] ?? nil {
                totalMrr += creatorMrr
            }
            for vote in feedback.votes {
                if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                    totalMrr += voterMrr
                }
            }

            return FeedbackResponseDTO(
                feedback: feedback,
                hasVoted: hasVoted,
                commentCount: feedback.comments.count,
                totalMrr: totalMrr > 0 ? totalMrr : nil
            )
        }
    }

    @Sendable
    func create(req: Request) async throws -> FeedbackResponseDTO {
        // Creating feedback requires active (non-archived) project
        let project = try await getProjectFromApiKey(req: req, requireActive: true)

        let dto = try req.content.decode(CreateFeedbackDTO.self)

        // Validate input
        guard !dto.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Title cannot be empty")
        }

        guard !dto.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Description cannot be empty")
        }

        guard !dto.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "User ID cannot be empty")
        }

        // Validate email if provided
        if let email = dto.userEmail, !email.isEmpty {
            let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
            guard email.range(of: emailRegex, options: .regularExpression) != nil else {
                throw Abort(.badRequest, reason: "Invalid email format")
            }
        }

        let feedback = Feedback(
            title: dto.title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: dto.description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: dto.category,
            userId: dto.userId,
            userEmail: dto.userEmail,
            projectId: project.id!
        )

        try await feedback.save(on: req.db)

        // Send email notification to project members who have feedback notifications enabled
        Task {
            do {
                try await project.$owner.load(on: req.db)
                let members = try await ProjectMember.query(on: req.db)
                    .filter(\.$project.$id == project.id!)
                    .with(\.$user)
                    .all()

                // Filter to users with feedback notifications enabled
                var emails: [String] = []
                if project.owner.notifyNewFeedback {
                    emails.append(project.owner.email)
                }
                for member in members where member.user.notifyNewFeedback {
                    emails.append(member.user.email)
                }

                try await req.emailService.sendNewFeedbackNotification(
                    to: emails,
                    projectName: project.name,
                    feedbackTitle: feedback.title,
                    feedbackCategory: feedback.category.rawValue,
                    feedbackDescription: feedback.description
                )
            } catch {
                req.logger.error("Failed to send new feedback notification: \(error)")
            }
        }

        return FeedbackResponseDTO(feedback: feedback)
    }

    @Sendable
    func show(req: Request) async throws -> FeedbackResponseDTO {
        guard let feedbackId = req.parameters.get("feedbackId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid feedback ID")
        }

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == feedbackId)
            .with(\.$votes)
            .with(\.$comments)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        let userId = req.headers.first(name: "X-User-Id")
        let hasVoted = userId.map { uid in feedback.votes.contains { $0.userId == uid } } ?? false

        return FeedbackResponseDTO(feedback: feedback, hasVoted: hasVoted, commentCount: feedback.comments.count)
    }

    @Sendable
    func update(req: Request) async throws -> FeedbackResponseDTO {
        let user = try req.auth.require(User.self)

        guard let feedbackId = req.parameters.get("feedbackId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid feedback ID")
        }

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == feedbackId)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        // Verify user has access to this project
        let userId = try user.requireID()
        guard try await feedback.project.userHasAccess(userId, on: req.db) else {
            throw Abort(.forbidden, reason: "You don't have access to this feedback")
        }

        let dto = try req.content.decode(UpdateFeedbackDTO.self)

        // Track old status for notification
        let oldStatus = feedback.status

        if let title = dto.title {
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Abort(.badRequest, reason: "Title cannot be empty")
            }
            feedback.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let description = dto.description {
            guard !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Abort(.badRequest, reason: "Description cannot be empty")
            }
            feedback.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let status = dto.status { feedback.status = status }
        if let category = dto.category { feedback.category = category }

        try await feedback.save(on: req.db)

        // Send status change notification if status changed
        if let newStatus = dto.status, newStatus != oldStatus {
            let project = feedback.project
            Task {
                do {
                    // Collect emails: feedback submitter (if provided) + voters with emails
                    var emails: [String] = []

                    // Add feedback submitter's email if provided
                    if let submitterEmail = feedback.userEmail, !submitterEmail.isEmpty {
                        emails.append(submitterEmail)
                    }

                    // Note: Votes currently don't store email addresses
                    // To notify voters, you would need to add userEmail field to Vote model

                    try await req.emailService.sendFeedbackStatusChangeNotification(
                        to: emails,
                        projectName: project.name,
                        feedbackTitle: feedback.title,
                        oldStatus: oldStatus.rawValue,
                        newStatus: newStatus.rawValue
                    )
                } catch {
                    req.logger.error("Failed to send status change notification: \(error)")
                }
            }
        }

        try await feedback.$votes.load(on: req.db)
        try await feedback.$comments.load(on: req.db)

        return FeedbackResponseDTO(feedback: feedback, commentCount: feedback.comments.count)
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try req.auth.require(User.self)

        guard let feedbackId = req.parameters.get("feedbackId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid feedback ID")
        }

        guard let feedback = try await Feedback.query(on: req.db)
            .filter(\.$id == feedbackId)
            .with(\.$project)
            .first() else {
            throw Abort(.notFound, reason: "Feedback not found")
        }

        // Verify user has access to this project (owner or admin only)
        let userId = try user.requireID()
        let project = feedback.project

        // Check if owner
        let isOwner = project.userIsOwner(userId)

        // Check if admin member
        let membership = try await ProjectMember.query(on: req.db)
            .filter(\.$project.$id == project.requireID())
            .filter(\.$user.$id == userId)
            .first()

        let isAdmin = membership?.role == .admin

        guard isOwner || isAdmin else {
            throw Abort(.forbidden, reason: "Only project owners or admins can delete feedback")
        }

        try await feedback.delete(on: req.db)
        return .noContent
    }
}
