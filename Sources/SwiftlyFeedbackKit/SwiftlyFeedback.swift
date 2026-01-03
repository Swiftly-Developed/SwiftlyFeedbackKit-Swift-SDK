import Foundation

/// Main entry point for the SwiftlyFeedback SDK
public final class SwiftlyFeedback: Sendable {
    public static var shared: SwiftlyFeedback?

    private let client: APIClient
    private let userId: String

    /// Initialize the SwiftlyFeedback SDK
    /// - Parameters:
    ///   - apiKey: Your project's API key from the SwiftlyFeedback dashboard
    ///   - userId: A unique identifier for the current user (can be anonymous UUID)
    ///   - baseURL: The base URL of your SwiftlyFeedback server (defaults to localhost for development)
    public init(apiKey: String, userId: String, baseURL: URL = URL(string: "http://localhost:8080/api/v1")!) {
        self.userId = userId
        self.client = APIClient(baseURL: baseURL, apiKey: apiKey, userId: userId)
    }

    /// Configure the shared instance of SwiftlyFeedback
    /// - Parameters:
    ///   - apiKey: Your project's API key
    ///   - userId: A unique identifier for the current user
    ///   - baseURL: The base URL of your SwiftlyFeedback server
    public static func configure(apiKey: String, userId: String, baseURL: URL = URL(string: "http://localhost:8080/api/v1")!) {
        shared = SwiftlyFeedback(apiKey: apiKey, userId: userId, baseURL: baseURL)
    }

    // MARK: - Feedback

    /// Fetch all feedback for the current project
    /// - Parameters:
    ///   - status: Optional filter by status
    ///   - category: Optional filter by category
    /// - Returns: Array of feedback items
    public func getFeedback(status: FeedbackStatus? = nil, category: FeedbackCategory? = nil) async throws -> [Feedback] {
        var path = "feedbacks"
        var queryItems: [String] = []

        if let status = status {
            queryItems.append("status=\(status.rawValue)")
        }
        if let category = category {
            queryItems.append("category=\(category.rawValue)")
        }

        if !queryItems.isEmpty {
            path += "?" + queryItems.joined(separator: "&")
        }

        return try await client.get(path: path)
    }

    /// Get a specific feedback item by ID
    /// - Parameter id: The feedback ID
    /// - Returns: The feedback item
    public func getFeedback(id: UUID) async throws -> Feedback {
        try await client.get(path: "feedbacks/\(id)")
    }

    /// Submit new feedback
    /// - Parameters:
    ///   - title: The title of the feedback
    ///   - description: Detailed description
    ///   - category: The category of feedback
    ///   - email: Optional user email for follow-up
    /// - Returns: The created feedback item
    public func submitFeedback(
        title: String,
        description: String,
        category: FeedbackCategory,
        email: String? = nil
    ) async throws -> Feedback {
        let body = CreateFeedbackRequest(
            title: title,
            description: description,
            category: category,
            userId: userId,
            userEmail: email
        )
        return try await client.post(path: "feedbacks", body: body)
    }

    // MARK: - Voting

    /// Vote for a feedback item
    /// - Parameter feedbackId: The ID of the feedback to vote for
    /// - Returns: Updated vote information
    public func vote(for feedbackId: UUID) async throws -> VoteResult {
        let body = VoteRequest(userId: userId)
        return try await client.post(path: "feedbacks/\(feedbackId)/votes", body: body)
    }

    /// Remove vote from a feedback item
    /// - Parameter feedbackId: The ID of the feedback to unvote
    /// - Returns: Updated vote information
    public func unvote(for feedbackId: UUID) async throws -> VoteResult {
        let body = VoteRequest(userId: userId)
        return try await client.delete(path: "feedbacks/\(feedbackId)/votes", body: body)
    }

    // MARK: - Comments

    /// Get comments for a feedback item
    /// - Parameter feedbackId: The ID of the feedback
    /// - Returns: Array of comments
    public func getComments(for feedbackId: UUID) async throws -> [Comment] {
        try await client.get(path: "feedbacks/\(feedbackId)/comments")
    }

    /// Add a comment to a feedback item
    /// - Parameters:
    ///   - feedbackId: The ID of the feedback
    ///   - content: The comment text
    /// - Returns: The created comment
    public func addComment(to feedbackId: UUID, content: String) async throws -> Comment {
        let body = CreateCommentRequest(content: content, userId: userId, isAdmin: nil)
        return try await client.post(path: "feedbacks/\(feedbackId)/comments", body: body)
    }
}

// MARK: - Request Models

private struct CreateFeedbackRequest: Encodable {
    let title: String
    let description: String
    let category: FeedbackCategory
    let userId: String
    let userEmail: String?
}

private struct VoteRequest: Encodable {
    let userId: String
}

private struct CreateCommentRequest: Encodable {
    let content: String
    let userId: String
    let isAdmin: Bool?
}
