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

extension Feedback {
    /// This item with the server's answer to a vote or unvote. The count is the server's, not
    /// an increment, so applying the same answer twice cannot count twice.
    func applying(_ vote: VoteResult) -> Feedback {
        Feedback(
            id: id,
            title: title,
            description: description,
            status: status,
            category: category,
            userId: userId,
            userEmail: userEmail,
            voteCount: vote.voteCount,
            hasVoted: vote.hasVoted,
            commentCount: commentCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            mergedIntoId: mergedIntoId,
            mergedAt: mergedAt,
            mergedFeedbackIds: mergedFeedbackIds,
            rejectionReason: rejectionReason,
            isHiddenOverLimit: isHiddenOverLimit
        )
    }
}
