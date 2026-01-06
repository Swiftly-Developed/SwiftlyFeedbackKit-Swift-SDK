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
        protected.post("merge", use: merge)
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
        let includeMerged = req.query[Bool.self, at: "includeMerged"] ?? false

        var query = Feedback.query(on: req.db)
            .filter(\.$project.$id == project.id!)
            .with(\.$votes)
            .with(\.$comments)

        // Filter out merged feedback by default
        if !includeMerged {
            query = query.filter(\.$mergedIntoId == nil)
        }

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

        // Send Slack notification if configured and active
        if let webhookURL = project.slackWebhookURL, project.slackIsActive, project.slackNotifyNewFeedback {
            Task {
                do {
                    try await req.slackService.sendNewFeedbackNotification(
                        webhookURL: webhookURL,
                        projectName: project.name,
                        feedbackTitle: feedback.title,
                        feedbackCategory: feedback.category.rawValue,
                        feedbackDescription: feedback.description,
                        userName: nil
                    )
                } catch {
                    req.logger.error("Failed to send Slack notification: \(error)")
                }
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

            // Send email notification
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

            // Send Slack notification if configured and active
            if let webhookURL = project.slackWebhookURL, project.slackIsActive, project.slackNotifyStatusChanges {
                Task {
                    do {
                        try await req.slackService.sendFeedbackStatusChangeNotification(
                            webhookURL: webhookURL,
                            projectName: project.name,
                            feedbackTitle: feedback.title,
                            oldStatus: oldStatus.rawValue,
                            newStatus: newStatus.rawValue
                        )
                    } catch {
                        req.logger.error("Failed to send Slack status notification: \(error)")
                    }
                }
            }

            // Sync to GitHub if configured and active
            if let issueNumber = feedback.githubIssueNumber,
               project.githubIsActive,
               project.githubSyncStatus,
               let owner = project.githubOwner,
               let repo = project.githubRepo,
               let token = project.githubToken {
                Task {
                    do {
                        if newStatus == .completed || newStatus == .rejected {
                            // Close the issue
                            try await req.githubService.closeIssue(
                                owner: owner,
                                repo: repo,
                                token: token,
                                issueNumber: issueNumber
                            )
                        } else if oldStatus == .completed || oldStatus == .rejected {
                            // Reopening from a closed status
                            try await req.githubService.reopenIssue(
                                owner: owner,
                                repo: repo,
                                token: token,
                                issueNumber: issueNumber
                            )
                        }
                    } catch {
                        req.logger.error("Failed to sync GitHub issue status: \(error)")
                    }
                }
            }

            // Sync to ClickUp if configured and active
            if let taskId = feedback.clickupTaskId,
               project.clickupIsActive,
               project.clickupSyncStatus,
               let token = project.clickupToken {
                // Map SwiftlyFeedback status to ClickUp status name
                let clickupStatus = newStatus.clickupStatusName
                Task {
                    do {
                        try await req.clickupService.updateTaskStatus(
                            taskId: taskId,
                            token: token,
                            status: clickupStatus
                        )
                    } catch {
                        req.logger.error("Failed to sync ClickUp task status: \(error)")
                    }
                }
            }

            // Sync to Notion if configured and active
            if let pageId = feedback.notionPageId,
               project.notionIsActive,
               project.notionSyncStatus,
               let token = project.notionToken,
               let statusProperty = project.notionStatusProperty,
               !statusProperty.isEmpty {
                let notionStatus = newStatus.notionStatusName
                Task {
                    do {
                        try await req.notionService.updatePageStatus(
                            pageId: pageId,
                            token: token,
                            statusProperty: statusProperty,
                            statusValue: notionStatus
                        )
                    } catch {
                        req.logger.error("Failed to sync Notion page status: \(error)")
                    }
                }
            }

            // Sync to Monday.com if configured and active
            if let itemId = feedback.mondayItemId,
               project.mondayIsActive,
               project.mondaySyncStatus,
               let token = project.mondayToken,
               let boardId = project.mondayBoardId,
               let statusColumnId = project.mondayStatusColumnId,
               !statusColumnId.isEmpty {
                let mondayStatus = newStatus.mondayStatusName
                Task {
                    do {
                        try await req.mondayService.updateItemStatus(
                            boardId: boardId,
                            itemId: itemId,
                            columnId: statusColumnId,
                            token: token,
                            status: mondayStatus
                        )
                    } catch {
                        req.logger.error("Failed to sync Monday.com item status: \(error)")
                    }
                }
            }

            // Sync to Linear if configured and active
            if let issueId = feedback.linearIssueId,
               project.linearIsActive,
               project.linearSyncStatus,
               let token = project.linearToken,
               let teamId = project.linearTeamId {
                let targetStateType = newStatus.linearStateType
                Task {
                    do {
                        // Fetch workflow states for the team and find matching state by type
                        let states = try await req.linearService.getWorkflowStates(teamId: teamId, token: token)
                        if let targetState = states.first(where: { $0.type == targetStateType }) {
                            try await req.linearService.updateIssueState(
                                issueId: issueId,
                                stateId: targetState.id,
                                token: token
                            )
                        }
                    } catch {
                        req.logger.error("Failed to sync Linear issue status: \(error)")
                    }
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

    @Sendable
    func merge(req: Request) async throws -> MergeFeedbackResponse {
        let user = try req.auth.require(User.self)
        let userId = try user.requireID()

        let dto = try req.content.decode(MergeFeedbackRequest.self)

        // Validate we have at least one secondary feedback
        guard !dto.secondaryFeedbackIds.isEmpty else {
            throw Abort(.badRequest, reason: "At least one secondary feedback ID is required")
        }

        // Validate primary is not in secondary list
        guard !dto.secondaryFeedbackIds.contains(dto.primaryFeedbackId) else {
            throw Abort(.badRequest, reason: "Primary feedback ID cannot be in secondary list")
        }

        // Fetch primary feedback with project
        guard let primaryFeedback = try await Feedback.query(on: req.db)
            .filter(\.$id == dto.primaryFeedbackId)
            .with(\.$project)
            .with(\.$votes)
            .with(\.$comments)
            .first() else {
            throw Abort(.notFound, reason: "Primary feedback not found")
        }

        let project = primaryFeedback.project
        let projectId = try project.requireID()

        // Verify user has admin/owner access
        let isOwner = project.userIsOwner(userId)
        let membership = try await ProjectMember.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$user.$id == userId)
            .first()
        let isAdmin = membership?.role == .admin

        guard isOwner || isAdmin else {
            throw Abort(.forbidden, reason: "Only project owners or admins can merge feedback")
        }

        // Check project is not archived
        guard !project.isArchived else {
            throw Abort(.forbidden, reason: "Cannot merge feedback in archived project")
        }

        // Validate primary feedback is not already merged
        guard primaryFeedback.mergedIntoId == nil else {
            throw Abort(.badRequest, reason: "Primary feedback has already been merged into another feedback")
        }

        // Fetch all secondary feedbacks
        let secondaryFeedbacks = try await Feedback.query(on: req.db)
            .filter(\.$id ~~ dto.secondaryFeedbackIds)
            .with(\.$votes)
            .with(\.$comments)
            .all()

        // Validate all secondary feedbacks were found
        guard secondaryFeedbacks.count == dto.secondaryFeedbackIds.count else {
            throw Abort(.notFound, reason: "One or more secondary feedbacks not found")
        }

        // Validate all feedbacks belong to the same project and none are already merged
        for feedback in secondaryFeedbacks {
            guard feedback.$project.id == projectId else {
                throw Abort(.badRequest, reason: "All feedback must belong to the same project")
            }
            guard feedback.mergedIntoId == nil else {
                throw Abort(.badRequest, reason: "Feedback '\(feedback.title)' has already been merged")
            }
        }

        // Begin merge operation
        let primaryId = try primaryFeedback.requireID()

        // Collect existing voter IDs from primary
        var existingVoterIds = Set(primaryFeedback.votes.map { $0.userId })

        // Process each secondary feedback
        for secondary in secondaryFeedbacks {
            // Migrate votes (de-duplicate by userId)
            for vote in secondary.votes {
                if !existingVoterIds.contains(vote.userId) {
                    // Create new vote on primary
                    let newVote = Vote(userId: vote.userId, feedbackId: primaryId)
                    try await newVote.save(on: req.db)
                    existingVoterIds.insert(vote.userId)
                }
            }

            // Migrate comments with context prefix
            for comment in secondary.comments {
                let prefixedContent = "[Originally on: \(secondary.title)] \(comment.content)"
                let newComment = Comment(
                    content: prefixedContent,
                    userId: comment.userId,
                    isAdmin: comment.isAdmin,
                    feedbackId: primaryId
                )
                try await newComment.save(on: req.db)
            }

            // Mark secondary as merged
            secondary.mergedIntoId = primaryId
            secondary.mergedAt = Date()
            try await secondary.save(on: req.db)
        }

        // Update primary feedback
        let mergedIds = dto.secondaryFeedbackIds
        primaryFeedback.mergedFeedbackIds = (primaryFeedback.mergedFeedbackIds ?? []) + mergedIds
        primaryFeedback.voteCount = existingVoterIds.count
        try await primaryFeedback.save(on: req.db)

        // Reload to get updated data
        try await primaryFeedback.$votes.load(on: req.db)
        try await primaryFeedback.$comments.load(on: req.db)

        // Calculate MRR for response
        let allUserIds = Set([primaryFeedback.userId] + primaryFeedback.votes.map { $0.userId })
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .filter(\.$userId ~~ Array(allUserIds))
            .all()
        let mrrByUserId = Dictionary(uniqueKeysWithValues: sdkUsers.map { ($0.userId, $0.mrr) })

        var totalMrr: Double = 0
        if let creatorMrr = mrrByUserId[primaryFeedback.userId] ?? nil {
            totalMrr += creatorMrr
        }
        for vote in primaryFeedback.votes {
            if let voterMrr = mrrByUserId[vote.userId] ?? nil {
                totalMrr += voterMrr
            }
        }

        let responseDTO = FeedbackResponseDTO(
            feedback: primaryFeedback,
            hasVoted: false,
            commentCount: primaryFeedback.comments.count,
            totalMrr: totalMrr > 0 ? totalMrr : nil
        )

        return MergeFeedbackResponse(
            primaryFeedback: responseDTO,
            mergedCount: secondaryFeedbacks.count,
            totalVotes: primaryFeedback.voteCount,
            totalComments: primaryFeedback.comments.count
        )
    }
}
