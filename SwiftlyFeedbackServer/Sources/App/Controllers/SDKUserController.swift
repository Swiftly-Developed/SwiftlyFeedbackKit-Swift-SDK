import Vapor
import Fluent

struct SDKUserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")

        // Public API routes (for SDK) - require API key
        users.post("register", use: registerOrUpdate)

        // Admin routes - require authentication
        let protected = users.grouped(UserToken.authenticator(), User.guardMiddleware())
        protected.get("project", ":projectId", use: getProjectUsers)
        protected.get("project", ":projectId", "stats", use: getProjectUserStats)
    }

    /// Get the project from API key
    private func getProjectFromApiKey(req: Request) async throws -> Project {
        guard let apiKey = req.headers.first(name: "X-API-Key") else {
            throw Abort(.unauthorized, reason: "API key required")
        }

        guard let project = try await Project.query(on: req.db)
            .filter(\.$apiKey == apiKey)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid API key")
        }

        return project
    }

    /// Register or update an SDK user
    @Sendable
    func registerOrUpdate(req: Request) async throws -> SDKUserResponseDTO {
        let project = try await getProjectFromApiKey(req: req)
        let dto = try req.content.decode(RegisterSDKUserDTO.self)

        guard !dto.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "User ID cannot be empty")
        }

        let projectId = try project.requireID()

        // Check if user already exists for this project
        if let existingUser = try await SDKUser.query(on: req.db)
            .filter(\.$userId == dto.userId)
            .filter(\.$project.$id == projectId)
            .first() {
            // Update existing user
            existingUser.mrr = dto.mrr
            try await existingUser.save(on: req.db)
            return SDKUserResponseDTO(sdkUser: existingUser)
        }

        // Create new user
        let newUser = SDKUser(
            userId: dto.userId.trimmingCharacters(in: .whitespacesAndNewlines),
            projectId: projectId,
            mrr: dto.mrr
        )
        try await newUser.save(on: req.db)
        return SDKUserResponseDTO(sdkUser: newUser)
    }

    /// Get all SDK users for a project (admin only)
    @Sendable
    func getProjectUsers(req: Request) async throws -> [SDKUserListResponseDTO] {
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

        // Get all SDK users for this project with their feedback and vote counts
        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .sort(\.$lastSeenAt, .descending)
            .all()

        // Get feedback counts per user
        let feedbacks = try await Feedback.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .all()

        let feedbackCounts = Dictionary(grouping: feedbacks, by: { $0.userId })
            .mapValues { $0.count }

        // Get vote counts per user
        let votes = try await Vote.query(on: req.db)
            .join(Feedback.self, on: \Vote.$feedback.$id == \Feedback.$id)
            .filter(Feedback.self, \.$project.$id == projectId)
            .all()

        let voteCounts = Dictionary(grouping: votes, by: { $0.userId })
            .mapValues { $0.count }

        return sdkUsers.map { sdkUser in
            SDKUserListResponseDTO(
                id: sdkUser.id!,
                userId: sdkUser.userId,
                mrr: sdkUser.mrr,
                feedbackCount: feedbackCounts[sdkUser.userId] ?? 0,
                voteCount: voteCounts[sdkUser.userId] ?? 0,
                firstSeenAt: sdkUser.firstSeenAt,
                lastSeenAt: sdkUser.lastSeenAt
            )
        }
    }

    /// Get SDK user statistics for a project (admin only)
    @Sendable
    func getProjectUserStats(req: Request) async throws -> SDKUsersStatsDTO {
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

        let sdkUsers = try await SDKUser.query(on: req.db)
            .filter(\.$project.$id == projectId)
            .all()

        let totalUsers = sdkUsers.count
        let usersWithMRR = sdkUsers.filter { $0.mrr != nil && $0.mrr! > 0 }
        let totalMRR = usersWithMRR.reduce(0.0) { $0 + ($1.mrr ?? 0) }
        let averageMRR = usersWithMRR.isEmpty ? 0 : totalMRR / Double(usersWithMRR.count)

        return SDKUsersStatsDTO(
            totalUsers: totalUsers,
            totalMRR: totalMRR,
            usersWithMRR: usersWithMRR.count,
            averageMRR: averageMRR
        )
    }
}
