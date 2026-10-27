import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// A vote cast from a list row lands on that row once: the count and the voted state are the
/// server's answer, written onto the loaded item, with no reload behind it.
///
/// The list used to discard the vote response and reload. A server whose list read lagged the
/// vote, or the Admin's demo stub, put the old count straight back, so voting from the list
/// looked like it did nothing while the detail screen, which applies the response, worked.
@Suite("Feedback list vote")
@MainActor
struct FeedbackListVoteTests {
    private static let baseURL = URL(string: "https://stub.invalid/api/v1")!

    private static func makeViewModel(stub: StubURLProtocol.Session, items: [Feedback]) async throws -> FeedbackListViewModel {
        let sf = SwiftlyFeedback(
            apiKey: "sf_test_stub_key_not_a_credential",
            userId: "user-under-test",
            baseURL: baseURL,
            session: stub.urlSession
        )
        stub.enqueueResponse(data: try WireCoding.makeEncoder().encode(items))
        let viewModel = FeedbackListViewModel(swiftlyFeedback: sf)
        await viewModel.loadFeedback()
        return viewModel
    }

    private static func voteResponse(_ result: VoteResult) throws -> Data {
        try WireCoding.makeEncoder().encode(result)
    }

    @Test("Unvoting from a row writes the server's count once and does not reload")
    func unvoteUpdatesTheRowOnce() async throws {
        let stub = StubURLProtocol.Session()
        let voted = FeedbackFixtures.make(voteCount: 41, hasVoted: true)
        let other = FeedbackFixtures.make(voteCount: 9, hasVoted: true)
        let viewModel = try await Self.makeViewModel(stub: stub, items: [voted, other])

        stub.enqueueResponse(data: try Self.voteResponse(VoteResult(feedbackId: voted.id, voteCount: 40, hasVoted: false)))
        await viewModel.submitVote(for: voted.id, email: nil, notify: false)

        let row = try #require(viewModel.feedbackItems.first { $0.id == voted.id })
        #expect(row.voteCount == 40)
        #expect(row.hasVoted == false)
        #expect(viewModel.feedbackItems.first { $0.id == other.id } == other)
        #expect(stub.recordedRequests.map(\.method) == ["GET", "DELETE"])
        #expect(viewModel.showingError == false)
    }

    @Test("Voting from a row writes the server's count once and does not reload")
    func voteUpdatesTheRowOnce() async throws {
        let stub = StubURLProtocol.Session()
        let unvoted = FeedbackFixtures.make(voteCount: 40, hasVoted: false)
        let viewModel = try await Self.makeViewModel(stub: stub, items: [unvoted])

        stub.enqueueResponse(data: try Self.voteResponse(VoteResult(feedbackId: unvoted.id, voteCount: 41, hasVoted: true)))
        await viewModel.submitVote(for: unvoted.id, email: nil, notify: false)

        let row = try #require(viewModel.feedbackItems.first)
        #expect(row.voteCount == 41)
        #expect(row.hasVoted)
        #expect(stub.recordedRequests.map(\.method) == ["GET", "POST"])
        #expect(viewModel.showingError == false)
    }

    @Test("The count is the server's, so a repeated answer cannot count twice")
    func repeatedAnswerDoesNotDoubleCount() async throws {
        let stub = StubURLProtocol.Session()
        let unvoted = FeedbackFixtures.make(voteCount: 40, hasVoted: false)
        let viewModel = try await Self.makeViewModel(stub: stub, items: [unvoted])
        let answer = VoteResult(feedbackId: unvoted.id, voteCount: 41, hasVoted: true)

        stub.enqueueResponse(data: try Self.voteResponse(answer))
        await viewModel.submitVote(for: unvoted.id, email: nil, notify: false)
        // A second submit for the same row while it already reads voted is an unvote; the
        // server answers with its own count, which the row takes as is.
        stub.enqueueResponse(data: try Self.voteResponse(VoteResult(feedbackId: unvoted.id, voteCount: 40, hasVoted: false)))
        await viewModel.submitVote(for: unvoted.id, email: nil, notify: false)

        let row = try #require(viewModel.feedbackItems.first)
        #expect(row.voteCount == 40)
        #expect(row.hasVoted == false)
        #expect(stub.recordedRequests.map(\.method) == ["GET", "POST", "DELETE"])
    }

    @Test("A vote keeps every other field of the row")
    func voteKeepsTheRestOfTheRow() {
        let original = Feedback(
            id: UUID(), title: "Dark mode", description: "Night reading", status: .approved,
            category: .improvement, userId: "author", userEmail: "a@example.com",
            voteCount: 7, hasVoted: false, commentCount: 3,
            createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 200),
            mergedIntoId: nil, mergedAt: nil, mergedFeedbackIds: [UUID()],
            rejectionReason: nil, isHiddenOverLimit: true
        )
        let updated = original.applying(VoteResult(feedbackId: original.id, voteCount: 8, hasVoted: true))

        #expect(updated.voteCount == 8)
        #expect(updated.hasVoted)
        #expect(updated == Feedback(
            id: original.id, title: original.title, description: original.description,
            status: original.status, category: original.category, userId: original.userId,
            userEmail: original.userEmail, voteCount: 8, hasVoted: true,
            commentCount: original.commentCount, createdAt: original.createdAt,
            updatedAt: original.updatedAt, mergedIntoId: original.mergedIntoId,
            mergedAt: original.mergedAt, mergedFeedbackIds: original.mergedFeedbackIds,
            rejectionReason: original.rejectionReason, isHiddenOverLimit: original.isHiddenOverLimit
        ))
    }
}
