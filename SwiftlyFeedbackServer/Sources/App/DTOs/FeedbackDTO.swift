import Vapor

struct CreateFeedbackDTO: Content {
    let title: String
    let description: String
    let category: FeedbackCategory
    let userId: String
    let userEmail: String?
}

struct UpdateFeedbackDTO: Content {
    let title: String?
    let description: String?
    let status: FeedbackStatus?
    let category: FeedbackCategory?
}

struct FeedbackResponseDTO: Content {
    let id: UUID
    let title: String
    let description: String
    let status: FeedbackStatus
    let category: FeedbackCategory
    let userId: String
    let userEmail: String?
    let voteCount: Int
    let hasVoted: Bool
    let commentCount: Int
    /// Total MRR from the feedback creator plus all voters
    let totalMrr: Double?
    let createdAt: Date?
    let updatedAt: Date?

    init(feedback: Feedback, hasVoted: Bool = false, commentCount: Int = 0, totalMrr: Double? = nil) {
        self.id = feedback.id!
        self.title = feedback.title
        self.description = feedback.description
        self.status = feedback.status
        self.category = feedback.category
        self.userId = feedback.userId
        self.userEmail = feedback.userEmail
        self.voteCount = feedback.voteCount
        self.hasVoted = hasVoted
        self.commentCount = commentCount
        self.totalMrr = totalMrr
        self.createdAt = feedback.createdAt
        self.updatedAt = feedback.updatedAt
    }
}
