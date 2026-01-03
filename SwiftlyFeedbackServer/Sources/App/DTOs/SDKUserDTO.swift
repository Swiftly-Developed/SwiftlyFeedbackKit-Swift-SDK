import Vapor

// MARK: - Request DTOs

struct RegisterSDKUserDTO: Content {
    let userId: String
    let mrr: Double?
}

// MARK: - Response DTOs

struct SDKUserResponseDTO: Content {
    let id: UUID
    let userId: String
    let mrr: Double?
    let firstSeenAt: Date?
    let lastSeenAt: Date?

    init(sdkUser: SDKUser) {
        self.id = sdkUser.id!
        self.userId = sdkUser.userId
        self.mrr = sdkUser.mrr
        self.firstSeenAt = sdkUser.firstSeenAt
        self.lastSeenAt = sdkUser.lastSeenAt
    }
}

struct SDKUserListResponseDTO: Content {
    let id: UUID
    let userId: String
    let mrr: Double?
    let feedbackCount: Int
    let voteCount: Int
    let firstSeenAt: Date?
    let lastSeenAt: Date?
}

struct SDKUsersStatsDTO: Content {
    let totalUsers: Int
    let totalMRR: Double
    let usersWithMRR: Int
    let averageMRR: Double
}
