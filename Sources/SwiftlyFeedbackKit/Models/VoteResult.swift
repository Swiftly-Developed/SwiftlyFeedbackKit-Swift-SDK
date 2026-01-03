import Foundation

public struct VoteResult: Codable, Sendable {
    public let feedbackId: UUID
    public let voteCount: Int
    public let hasVoted: Bool

    public init(feedbackId: UUID, voteCount: Int, hasVoted: Bool) {
        self.feedbackId = feedbackId
        self.voteCount = voteCount
        self.hasVoted = hasVoted
    }
}
