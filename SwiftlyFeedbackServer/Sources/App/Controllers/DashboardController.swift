import Vapor
import Fluent

struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let dashboard = routes.grouped("dashboard")

        // All dashboard routes require authentication
        let protected = dashboard.grouped(UserToken.authenticator(), User.guardMiddleware())
        protected.get("home", use: getHomeDashboard)
        protected.get("project", ":projectId", use: getProjectDashboard)
    }

    /// Get home dashboard with aggregated stats across all user's projects
    @Sendable
    func getHomeDashboard(req: Request) async throws -> HomeDashboardDTO {
        let user = try req.auth.require(User.self)
        let userId = try user.requireID()

        // Get all projects the user has access to (owned + member)
        let ownedProjects = try await Project.query(on: req.db)
            .filter(\.$owner.$id == userId)
            .all()

        let memberProjectIds = try await ProjectMember.query(on: req.db)
            .filter(\.$user.$id == userId)
            .all()
            .map { $0.$project.id }

        let memberProjects = try await Project.query(on: req.db)
            .filter(\.$id ~~ memberProjectIds)
            .all()

        let allProjects = ownedProjects + memberProjects
        let projectIds = allProjects.compactMap { $0.id }

        // Get all feedbacks for these projects
        let allFeedbacks = try await Feedback.query(on: req.db)
            .filter(\.$project.$id ~~ projectIds)
            .all()

        // Get all SDK users for these projects
        let allUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id ~~ projectIds)
            .all()

        // Get all comments for feedbacks in these projects
        let feedbackIds = allFeedbacks.compactMap { $0.id }
        let allComments = try await Comment.query(on: req.db)
            .filter(\.$feedback.$id ~~ feedbackIds)
            .all()

        // Calculate global totals
        let totalVotes = allFeedbacks.reduce(0) { $0 + $1.voteCount }

        // Calculate feedback by status (global)
        let globalFeedbackByStatus = calculateFeedbackByStatus(feedbacks: allFeedbacks)
        let globalFeedbackByCategory = calculateFeedbackByCategory(feedbacks: allFeedbacks)

        // Calculate per-project stats
        var projectStats: [ProjectStatsDTO] = []
        for project in allProjects {
            guard let projectId = project.id else { continue }

            let projectFeedbacks = allFeedbacks.filter { $0.$project.id == projectId }
            let projectUsers = allUsers.filter { $0.$project.id == projectId }
            let projectFeedbackIds = projectFeedbacks.compactMap { $0.id }
            let projectComments = allComments.filter { projectFeedbackIds.contains($0.$feedback.id) }
            let projectVotes = projectFeedbacks.reduce(0) { $0 + $1.voteCount }

            let stats = ProjectStatsDTO(
                id: projectId,
                name: project.name,
                isArchived: project.isArchived,
                colorIndex: project.colorIndex,
                feedbackCount: projectFeedbacks.count,
                feedbackByStatus: calculateFeedbackByStatus(feedbacks: projectFeedbacks),
                feedbackByCategory: calculateFeedbackByCategory(feedbacks: projectFeedbacks),
                userCount: projectUsers.count,
                commentCount: projectComments.count,
                voteCount: projectVotes
            )
            projectStats.append(stats)
        }

        // Sort projects by feedback count descending
        projectStats.sort { $0.feedbackCount > $1.feedbackCount }

        return HomeDashboardDTO(
            totalProjects: allProjects.count,
            totalFeedback: allFeedbacks.count,
            feedbackByStatus: globalFeedbackByStatus,
            feedbackByCategory: globalFeedbackByCategory,
            totalUsers: allUsers.count,
            totalComments: allComments.count,
            totalVotes: totalVotes,
            projectStats: projectStats
        )
    }

    /// Get dashboard stats for a specific project
    @Sendable
    func getProjectDashboard(req: Request) async throws -> ProjectStatsDTO {
        let user = try req.auth.require(User.self)

        guard let projectId = req.parameters.get("projectId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        guard let project = try await Project.find(projectId, on: req.db) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        // Verify user has access to this project
        let userId = try user.requireID()
        guard try await project.userHasAccess(userId, on: req.db) else {
            throw Abort(.forbidden, reason: "You don't have access to this project")
        }

        // Get all feedbacks for this project
        let feedbacks = try await Feedback.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .all()

        // Get all SDK users for this project
        let users = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .all()

        // Get all comments for feedbacks in this project
        let feedbackIds = feedbacks.compactMap { $0.id }
        let comments = try await Comment.query(on: req.db)
            .filter(\.$feedback.$id ~~ feedbackIds)
            .all()

        let totalVotes = feedbacks.reduce(0) { $0 + $1.voteCount }

        return ProjectStatsDTO(
            id: projectId,
            name: project.name,
            isArchived: project.isArchived,
            colorIndex: project.colorIndex,
            feedbackCount: feedbacks.count,
            feedbackByStatus: calculateFeedbackByStatus(feedbacks: feedbacks),
            feedbackByCategory: calculateFeedbackByCategory(feedbacks: feedbacks),
            userCount: users.count,
            commentCount: comments.count,
            voteCount: totalVotes
        )
    }

    // MARK: - Helper Methods

    private func calculateFeedbackByStatus(feedbacks: [Feedback]) -> FeedbackByStatusDTO {
        var pending = 0
        var approved = 0
        var inProgress = 0
        var testflight = 0
        var completed = 0
        var rejected = 0

        for feedback in feedbacks {
            switch feedback.status {
            case .pending: pending += 1
            case .approved: approved += 1
            case .inProgress: inProgress += 1
            case .testflight: testflight += 1
            case .completed: completed += 1
            case .rejected: rejected += 1
            }
        }

        return FeedbackByStatusDTO(
            pending: pending,
            approved: approved,
            inProgress: inProgress,
            testflight: testflight,
            completed: completed,
            rejected: rejected
        )
    }

    private func calculateFeedbackByCategory(feedbacks: [Feedback]) -> FeedbackByCategoryDTO {
        var featureRequest = 0
        var bugReport = 0
        var improvement = 0
        var other = 0

        for feedback in feedbacks {
            switch feedback.category {
            case .featureRequest: featureRequest += 1
            case .bugReport: bugReport += 1
            case .improvement: improvement += 1
            case .other: other += 1
            }
        }

        return FeedbackByCategoryDTO(
            featureRequest: featureRequest,
            bugReport: bugReport,
            improvement: improvement,
            other: other
        )
    }
}
