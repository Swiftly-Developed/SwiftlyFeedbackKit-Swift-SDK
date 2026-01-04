import Vapor

// MARK: - Home Dashboard DTOs

/// Statistics for feedback broken down by status
struct FeedbackByStatusDTO: Content {
    let pending: Int
    let approved: Int
    let inProgress: Int
    let testflight: Int
    let completed: Int
    let rejected: Int
}

/// Statistics for feedback broken down by category
struct FeedbackByCategoryDTO: Content {
    let featureRequest: Int
    let bugReport: Int
    let improvement: Int
    let other: Int
}

/// Per-project statistics for the home dashboard
struct ProjectStatsDTO: Content {
    let id: UUID
    let name: String
    let isArchived: Bool
    let colorIndex: Int
    let feedbackCount: Int
    let feedbackByStatus: FeedbackByStatusDTO
    let feedbackByCategory: FeedbackByCategoryDTO
    let userCount: Int
    let commentCount: Int
    let voteCount: Int
}

/// Home dashboard overview response
struct HomeDashboardDTO: Content {
    let totalProjects: Int
    let totalFeedback: Int
    let feedbackByStatus: FeedbackByStatusDTO
    let feedbackByCategory: FeedbackByCategoryDTO
    let totalUsers: Int
    let totalComments: Int
    let totalVotes: Int
    let projectStats: [ProjectStatsDTO]
}
