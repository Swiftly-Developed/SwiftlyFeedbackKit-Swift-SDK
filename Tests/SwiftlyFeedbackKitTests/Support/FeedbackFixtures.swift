import Foundation
@testable import SwiftlyFeedbackKit

/// Minimal `Feedback` values for list-logic tests. Each call gets a fresh id unless one is given.
enum FeedbackFixtures {
    static func make(
        id: UUID = UUID(),
        title: String = "Title",
        description: String = "Description",
        status: FeedbackStatus = .pending,
        category: FeedbackCategory = .featureRequest,
        voteCount: Int = 0,
        hasVoted: Bool = false,
        commentCount: Int = 0,
        createdAt: Date? = nil
    ) -> Feedback {
        Feedback(
            id: id,
            title: title,
            description: description,
            status: status,
            category: category,
            userId: "fixture",
            userEmail: nil,
            voteCount: voteCount,
            hasVoted: hasVoted,
            commentCount: commentCount,
            createdAt: createdAt,
            updatedAt: nil
        )
    }
}
