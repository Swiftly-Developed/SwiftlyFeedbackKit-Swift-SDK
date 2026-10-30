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

// `testCommentModel` was removed by `QA-UNIT04-COMMENTS` `-10`. It constructed a `Comment`
// and read back two of the five arguments it had just passed in, so no product change could
// make it fail. `CommentDecodeTests` covers the same type against the corpus the server
// actually emits.
//
// ⚠️ `docs/testing/L1-CLASSIFICATION.md` §1's `QA-UNIT04-COMMENTS` row still assigns
// `--filter "testCommentModel"`, which now selects nothing. It must be replaced with
// `CommentDecodeTests` (here) plus `MergeOriginPrefixTests` and `CommentWireContractTests`
// on the server target.

@Test(.isolatedSharedClient) func testSwiftlyFeedbackConfiguration() async throws {
    let baseURL = URL(string: "https://api.example.com")!
    SwiftlyFeedback.configure(with: "test_key", baseURL: baseURL)

    // Waits for the publish rather than for a fixed time, so that it cannot land after this
    // test has given up `current` and inside another test that holds it.
    let published = await SwiftlyFeedback.waitForCurrent(timeout: .seconds(10))
    #expect(published != nil)
}
