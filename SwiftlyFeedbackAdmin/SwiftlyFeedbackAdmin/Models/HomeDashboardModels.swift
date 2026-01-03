import Foundation

// MARK: - Feedback Statistics by Status

struct FeedbackByStatus: Codable, Equatable, Sendable {
    let pending: Int
    let approved: Int
    let inProgress: Int
    let completed: Int
    let rejected: Int

    var total: Int {
        pending + approved + inProgress + completed + rejected
    }
}

// MARK: - Feedback Statistics by Category

struct FeedbackByCategory: Codable, Equatable, Sendable {
    let featureRequest: Int
    let bugReport: Int
    let improvement: Int
    let other: Int

    var total: Int {
        featureRequest + bugReport + improvement + other
    }
}

// MARK: - Per-Project Statistics

struct ProjectStats: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let isArchived: Bool
    let feedbackCount: Int
    let feedbackByStatus: FeedbackByStatus
    let feedbackByCategory: FeedbackByCategory
    let userCount: Int
    let commentCount: Int
    let voteCount: Int
}

// MARK: - Home Dashboard Overview

struct HomeDashboard: Codable, Equatable, Sendable {
    let totalProjects: Int
    let totalFeedback: Int
    let feedbackByStatus: FeedbackByStatus
    let feedbackByCategory: FeedbackByCategory
    let totalUsers: Int
    let totalComments: Int
    let totalVotes: Int
    let projectStats: [ProjectStats]
}
