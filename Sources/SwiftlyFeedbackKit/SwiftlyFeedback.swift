import Foundation

/// Main entry point for the SwiftlyFeedback SDK.
///
/// ## Setup
///
/// Configure the SDK early in your app lifecycle:
///
/// ```swift
/// // In your App's init or AppDelegate
/// SwiftlyFeedback.configure(with: "your_api_key")
/// ```
///
/// ## Configuration
///
/// Customize behavior through `SwiftlyFeedback.config`:
///
/// ```swift
/// SwiftlyFeedback.config.allowUndoVote = false
/// SwiftlyFeedback.config.showCommentSection = true
/// ```
///
/// ## Theming
///
/// Customize appearance through `SwiftlyFeedback.theme`:
///
/// ```swift
/// SwiftlyFeedback.theme.primaryColor = .color(.blue)
/// SwiftlyFeedback.theme.statusColors.completed = .green
/// ```
///
/// ## User Data
///
/// Update user information for segmentation:
///
/// ```swift
/// SwiftlyFeedback.updateUser(customID: "user_123")
/// SwiftlyFeedback.updateUser(payment: .monthly(9.99))
/// ```
///
/// ## View Tracking
///
/// Track custom events and views:
///
/// ```swift
/// SwiftlyFeedback.view("feature_details", properties: ["id": "abc123"])
/// SwiftlyFeedback.view(.feedbackList)
/// ```
public final class SwiftlyFeedback: @unchecked Sendable {

    // MARK: - Static Properties

    /// Configuration options. Access via `SwiftlyFeedback.config`.
    public nonisolated(unsafe) static var config = SwiftlyFeedbackConfiguration()

    /// Theme configuration. Access via `SwiftlyFeedback.theme`.
    public nonisolated(unsafe) static var theme = SwiftlyFeedbackTheme()

    /// The shared instance. Available after calling `configure(with:)`.
    public nonisolated(unsafe) static var shared: SwiftlyFeedback?

    // MARK: - Instance Properties

    internal let client: APIClient
    internal let userId: String
    private var currentMRR: Double?

    // MARK: - Configuration

    // MARK: - Simple Environment Configuration (Recommended)

    /// Configure the SDK with an explicit environment and API key.
    ///
    /// This is the recommended configuration method. Use compiler flags to
    /// select the appropriate environment:
    ///
    /// ```swift
    /// init() {
    ///     #if DEBUG
    ///     SwiftlyFeedback.configure(environment: .development, key: "dev-api-key")
    ///     #elseif TESTFLIGHT
    ///     SwiftlyFeedback.configure(environment: .testflight, key: "staging-api-key")
    ///     #else
    ///     SwiftlyFeedback.configure(environment: .production, key: "prod-api-key")
    ///     #endif
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - environment: The server environment to connect to
    ///   - key: Your project's API key for this environment
    ///
    /// - Note: To use the `TESTFLIGHT` compiler flag, add it to your project's
    ///   build settings under "Active Compilation Conditions" for your TestFlight
    ///   build configuration.
    public static func configure(environment: Environment, key: String) {
        configure(with: key, baseURL: environment.serverURL)
        SDKLogger.info("Configured for \(environment.displayName)")
    }

    // MARK: - Multi-Environment Auto-Configuration

    /// Configures the SDK with environment-specific API keys.
    ///
    /// This method automatically detects the current build environment and
    /// selects the appropriate API key and server URL:
    ///
    /// | Build Type | Server | API Key Used |
    /// |------------|--------|--------------|
    /// | DEBUG | localhost:8080 | `keys.debug` (or `keys.testflight` if nil) |
    /// | TestFlight | staging server | `keys.testflight` |
    /// | App Store | production server | `keys.production` |
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // In your App's init or AppDelegate
    /// SwiftlyFeedback.configureAuto(keys: EnvironmentAPIKeys(
    ///     debug: "sf_local_...",        // Optional
    ///     testflight: "sf_staging_...",  // Required
    ///     production: "sf_prod_..."      // Required
    /// ))
    /// ```
    ///
    /// - Parameter keys: Environment-specific API keys configuration.
    ///
    /// - Note: For security, consider storing API keys in your app's
    ///   Info.plist or using a secrets management solution rather than
    ///   hardcoding them in source code.
    public static func configureAuto(keys: EnvironmentAPIKeys) {
        let apiKey = keys.currentKey
        let baseURL = keys.currentServerURL

        configure(with: apiKey, baseURL: baseURL)

        SDKLogger.info("Auto-configured for \(keys.currentEnvironmentName)")

        #if DEBUG
        // In DEBUG, log which key type is being used
        if keys.debug != nil {
            SDKLogger.debug("Using dedicated DEBUG API key")
        } else {
            SDKLogger.debug("Using TestFlight API key (no DEBUG key provided)")
        }
        #endif
    }

    /// Configure the SDK with automatic server detection based on build type.
    ///
    /// The server URL is automatically selected based on your build configuration:
    /// - DEBUG builds → localhost:8080
    /// - TestFlight builds → staging server
    /// - App Store builds → production server
    ///
    /// Call this early in your app lifecycle (e.g., in `App.init()` or `AppDelegate`).
    ///
    /// ```swift
    /// SwiftlyFeedback.configureAuto(with: "your_api_key")
    /// ```
    ///
    /// - Parameter apiKey: Your project's API key from the SwiftlyFeedback dashboard
    ///
    /// - Important: This method uses a single API key for all environments,
    ///   which may cause authentication failures when switching between
    ///   DEBUG, TestFlight, and App Store builds. Consider using
    ///   ``configureAuto(keys:)`` instead for multi-environment support.
    @available(*, deprecated, message: "Use configureAuto(keys:) for multi-environment support")
    public static func configureAuto(with apiKey: String) {
        let baseURL = detectServerURL()
        configure(with: apiKey, baseURL: baseURL)

        #if DEBUG
        SDKLogger.info("Auto-configured with localhost (DEBUG)")
        #else
        if BuildEnvironment.isTestFlight {
            SDKLogger.info("Auto-configured with staging (TestFlight)")
        } else {
            SDKLogger.info("Auto-configured with production (App Store)")
        }
        #endif
    }

    /// Configure the SDK with your API key (defaults to localhost).
    ///
    /// Call this early in your app lifecycle (e.g., in `App.init()` or `AppDelegate`).
    ///
    /// ```swift
    /// SwiftlyFeedback.configure(with: "your_api_key")
    /// ```
    ///
    /// - Parameter apiKey: Your project's API key from the SwiftlyFeedback dashboard
    public static func configure(with apiKey: String) {
        configure(with: apiKey, baseURL: URL(string: "http://localhost:8080/api/v1")!)
    }

    /// Configure the SDK with your API key and custom server URL.
    ///
    /// - Parameters:
    ///   - apiKey: Your project's API key
    ///   - baseURL: The base URL of your SwiftlyFeedback server
    public static func configure(with apiKey: String, baseURL: URL) {
        Task {
            let userId = await UserIdentifier.getOrCreateUserId()

            let instance = SwiftlyFeedback(
                apiKey: apiKey,
                userId: userId,
                baseURL: baseURL
            )
            shared = instance

            // Register user with server
            await instance.registerUser()
        }
    }

    /// Detect the appropriate server URL based on build environment
    private static func detectServerURL() -> URL {
        #if DEBUG
        // DEBUG builds → localhost
        return URL(string: "http://localhost:8080/api/v1")!
        #else
        if BuildEnvironment.isTestFlight {
            // TestFlight builds → staging
            return URL(string: "https://api.feedbackkit.testflight.swiftly-developed.com/api/v1")!
        } else {
            // App Store builds → production
            return URL(string: "https://api.feedbackkit.prod.swiftly-developed.com/api/v1")!
        }
        #endif
    }

    // MARK: - User Updates

    /// Payment frequency for MRR calculation.
    public enum Payment: Sendable {
        case weekly(Double)
        case monthly(Double)
        case quarterly(Double)
        case yearly(Double)

        var mrr: Double {
            switch self {
            case .weekly(let amount):
                return amount * (52.0 / 12.0)
            case .monthly(let amount):
                return amount
            case .quarterly(let amount):
                return amount / 3.0
            case .yearly(let amount):
                return amount / 12.0
            }
        }
    }

    /// Update the user's payment/subscription information for MRR tracking.
    ///
    /// ```swift
    /// SwiftlyFeedback.updateUser(payment: .monthly(9.99))
    /// SwiftlyFeedback.updateUser(payment: .yearly(99.99))
    /// ```
    ///
    /// - Parameter payment: The payment amount and frequency
    public static func updateUser(payment: Payment) {
        Task {
            await shared?.updateMRR(payment.mrr)
        }
    }

    /// Clear the user's payment information (e.g., when subscription is cancelled).
    public static func clearUserPayment() {
        Task {
            await shared?.updateMRR(nil)
        }
    }

    /// Update the user's custom identifier.
    ///
    /// Use this to link the SwiftlyFeedback user to your own user system.
    ///
    /// ```swift
    /// SwiftlyFeedback.updateUser(customID: "user_123")
    /// ```
    ///
    /// - Parameter customID: Your app's user identifier
    public static func updateUser(customID: String) {
        UserIdentifier.setCustomUserId(customID)
        // Re-register with new ID
        Task {
            if let instance = shared {
                await instance.registerUser()
            }
        }
    }

    /// Update the user's email address.
    ///
    /// Note: Email is only used for feedback submissions, not stored on the user record.
    ///
    /// - Parameter email: The user's email address
    @available(*, deprecated, message: "Email is set per-feedback submission, not globally")
    public static func updateUser(email: String) {
        // Email is handled per-feedback, not stored globally
    }

    // MARK: - Initialization

    private init(apiKey: String, userId: String, baseURL: URL) {
        self.userId = userId
        self.client = APIClient(baseURL: baseURL, apiKey: apiKey, userId: userId)
    }

    // MARK: - User Registration

    private func registerUser() async {
        await updateUserOnServer(mrr: currentMRR)
    }

    private func updateMRR(_ mrr: Double?) async {
        currentMRR = mrr
        await updateUserOnServer(mrr: mrr)
    }

    private func updateUserOnServer(mrr: Double?) async {
        do {
            let body = RegisterUserRequest(userId: userId, mrr: mrr)
            let _: RegisterUserResponse = try await client.post(path: "users/register", body: body)
        } catch {
            // Silently fail - user registration is not critical
            SDKLogger.error("Failed to register user: \(error)")
        }
    }

    // MARK: - Feedback

    /// Fetch all feedback for the current project.
    ///
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

    /// Get a specific feedback item by ID.
    ///
    /// - Parameter id: The feedback ID
    /// - Returns: The feedback item
    public func getFeedback(id: UUID) async throws -> Feedback {
        try await client.get(path: "feedbacks/\(id)")
    }

    /// Submit new feedback.
    ///
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

    /// Vote for a feedback item with optional email for status notifications.
    ///
    /// - Parameters:
    ///   - feedbackId: The ID of the feedback to vote for
    ///   - email: Optional email to receive status change notifications
    ///   - notifyStatusChange: Whether to receive notifications when status changes (requires email)
    /// - Returns: Updated vote information
    public func vote(
        for feedbackId: UUID,
        email: String? = nil,
        notifyStatusChange: Bool = false
    ) async throws -> VoteResult {
        let body = VoteRequest(
            userId: userId,
            email: email,
            notifyStatusChange: email != nil ? notifyStatusChange : false
        )
        return try await client.post(path: "feedbacks/\(feedbackId)/votes", body: body)
    }

    /// Remove vote from a feedback item.
    ///
    /// - Parameter feedbackId: The ID of the feedback to unvote
    /// - Returns: Updated vote information
    public func unvote(for feedbackId: UUID) async throws -> VoteResult {
        let body = VoteRequest(userId: userId, email: nil, notifyStatusChange: nil)
        return try await client.delete(path: "feedbacks/\(feedbackId)/votes", body: body)
    }

    // MARK: - Comments

    /// Get comments for a feedback item.
    ///
    /// - Parameter feedbackId: The ID of the feedback
    /// - Returns: Array of comments
    public func getComments(for feedbackId: UUID) async throws -> [Comment] {
        try await client.get(path: "feedbacks/\(feedbackId)/comments")
    }

    /// Add a comment to a feedback item.
    ///
    /// - Parameters:
    ///   - feedbackId: The ID of the feedback
    ///   - content: The comment text
    /// - Returns: The created comment
    public func addComment(to feedbackId: UUID, content: String) async throws -> Comment {
        let body = CreateCommentRequest(content: content, userId: userId, isAdmin: nil)
        return try await client.post(path: "feedbacks/\(feedbackId)/comments", body: body)
    }

    // MARK: - View Tracking

    /// Track a custom view or event.
    ///
    /// ```swift
    /// SwiftlyFeedback.view("feature_details", properties: ["id": "abc123"])
    /// ```
    ///
    /// - Parameters:
    ///   - name: The name of the view/event to track
    ///   - properties: Optional key-value properties for additional context
    public static func view(_ name: String, properties: [String: String]? = nil) {
        Task {
            await shared?.trackView(name: name, properties: properties)
        }
    }

    /// Track a predefined SDK view.
    ///
    /// ```swift
    /// SwiftlyFeedback.view(.feedbackList)
    /// ```
    ///
    /// - Parameters:
    ///   - predefined: The predefined view to track
    ///   - properties: Optional key-value properties for additional context
    public static func view(_ predefined: PredefinedView, properties: [String: String]? = nil) {
        view(predefined.rawValue, properties: properties)
    }

    /// Internal method to track a view event.
    internal func trackView(name: String, properties: [String: String]?) async {
        do {
            let body = TrackViewEventRequest(eventName: name, userId: userId, properties: properties)
            let _: ViewEventResponse = try await client.post(path: "events/track", body: body)
        } catch {
            // Silently fail - view tracking is not critical
            SDKLogger.error("Failed to track view '\(name)': \(error)")
        }
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
    let email: String?
    let notifyStatusChange: Bool?
}

private struct CreateCommentRequest: Encodable {
    let content: String
    let userId: String
    let isAdmin: Bool?
}

private struct RegisterUserRequest: Encodable {
    let userId: String
    let mrr: Double?
}

private struct RegisterUserResponse: Decodable {
    let userId: String
    let mrr: Double?
}

private struct TrackViewEventRequest: Encodable {
    let eventName: String
    let userId: String
    let properties: [String: String]?
}
