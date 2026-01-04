import Foundation

// MARK: - Feedback Statistics by Status

struct FeedbackByStatus: Codable, Equatable, Sendable {
    let pending: Int
    let approved: Int
    let inProgress: Int
    let testflight: Int
    let completed: Int
    let rejected: Int

    var total: Int {
        pending + approved + inProgress + testflight + completed + rejected
    }

    // Custom decoder to handle backwards compatibility when testflight is missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pending = try container.decode(Int.self, forKey: .pending)
        approved = try container.decode(Int.self, forKey: .approved)
        inProgress = try container.decode(Int.self, forKey: .inProgress)
        testflight = try container.decodeIfPresent(Int.self, forKey: .testflight) ?? 0
        completed = try container.decode(Int.self, forKey: .completed)
        rejected = try container.decode(Int.self, forKey: .rejected)
    }

    init(pending: Int, approved: Int, inProgress: Int, testflight: Int, completed: Int, rejected: Int) {
        self.pending = pending
        self.approved = approved
        self.inProgress = inProgress
        self.testflight = testflight
        self.completed = completed
        self.rejected = rejected
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
    let colorIndex: Int
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
