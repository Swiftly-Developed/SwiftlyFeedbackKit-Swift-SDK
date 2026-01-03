import Testing
import Foundation
@testable import SwiftlyFeedbackKit

@Test func testFeedbackStatusDisplayName() async throws {
    #expect(FeedbackStatus.pending.displayName == "Pending")
    #expect(FeedbackStatus.inProgress.displayName == "In Progress")
    #expect(FeedbackStatus.completed.displayName == "Completed")
}

@Test func testFeedbackCategoryDisplayName() async throws {
    #expect(FeedbackCategory.featureRequest.displayName == "Feature Request")
    #expect(FeedbackCategory.bugReport.displayName == "Bug Report")
}

@Test func testFeedbackModel() async throws {
    let feedback = Feedback(
        id: UUID(),
        title: "Test Feature",
        description: "A test description",
        status: .pending,
        category: .featureRequest,
        userId: "user123",
        userEmail: "test@example.com",
        voteCount: 5,
        hasVoted: false,
        commentCount: 2,
        createdAt: Date(),
        updatedAt: nil
    )

    #expect(feedback.title == "Test Feature")
    #expect(feedback.voteCount == 5)
    #expect(feedback.hasVoted == false)
}

@Test func testCommentModel() async throws {
    let comment = Comment(
        id: UUID(),
        content: "Great idea!",
        userId: "user456",
        isAdmin: false,
        createdAt: Date()
    )

    #expect(comment.content == "Great idea!")
    #expect(comment.isAdmin == false)
}

@Test func testSwiftlyFeedbackConfiguration() async throws {
    let baseURL = URL(string: "https://api.example.com")!
    SwiftlyFeedback.configure(apiKey: "test_key", userId: "user123", baseURL: baseURL)

    #expect(SwiftlyFeedback.shared != nil)
}
