import Foundation
import os

/// Main entry point for the SwiftlyFeedback SDK.
///
/// ## Setup
///
/// Configure the SDK early in your app lifecycle. `configure(with:)` talks to
/// localhost. Production hosts pass an environment:
///
/// ```swift
/// SwiftlyFeedback.configure(environment: .production, key: "your_api_key")
/// ```
///
/// ## Configuration
///
/// Customize behavior through `SwiftlyFeedback.configuration`:
///
/// ```swift
/// SwiftlyFeedback.configuration.allowUndoVote = false
/// SwiftlyFeedback.configuration.showCommentSection = true
/// ```
///
/// ## Theming
///
/// Customize appearance through `SwiftlyFeedback.appearance`:
///
/// ```swift
/// SwiftlyFeedback.appearance.primaryColor = .color(.blue)
/// SwiftlyFeedback.appearance.statusColors.completed = .color(.green)
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

    /// Behavior options for the SDK views. Read and write this on the main actor.
    @MainActor
    public static var configuration = SwiftlyFeedbackConfiguration() {
        didSet { SDKLogGate.setEnabled(configuration.loggingEnabled) }
    }

    /// Colors for the SDK views. Read and write this on the main actor.
    @MainActor
    public static var appearance = SwiftlyFeedbackTheme()

    /// The configured client, once ``configure(with:baseURL:)`` has resolved a user id.
    ///
    /// `nil` until configuration finishes. Views read this when they are created without
    /// an explicit client.
    @MainActor
    public static var current: SwiftlyFeedback?

    /// Behavior options. Forwards to ``configuration``.
    @available(*, deprecated, message: "Use SwiftlyFeedback.configuration instead")
    @MainActor
    public static var config: SwiftlyFeedbackConfiguration {
        get { configuration }
        set { configuration = newValue }
    }

    /// Colors for the SDK views. Forwards to ``appearance``.
    @available(*, deprecated, message: "Use SwiftlyFeedback.appearance instead")
    @MainActor
    public static var theme: SwiftlyFeedbackTheme {
        get { appearance }
        set { appearance = newValue }
    }

    /// The configured client. Forwards to ``current``.
    @available(*, deprecated, message: "Use SwiftlyFeedback.current instead")
    @MainActor
    public static var shared: SwiftlyFeedback? {
        get { current }
        set { current = newValue }
    }

    /// The configured client, read from the main actor for a nonisolated caller.
    private static func configuredClient() async -> SwiftlyFeedback? {
        await MainActor.run { current }
    }

    // MARK: - Instance Properties

    internal let client: APIClient
    /// The caller's payment, guarded because `updateUser(payment:)` can overlap `configure`.
    private let storedMRR = OSAllocatedUnfairLock<Double?>(initialState: nil)

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
    public static func configure(environment: FeedbackEnvironment, key: String) {
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
    /// | DEBUG | development API | `keys.debug` (or `keys.testflight` if nil) |
    /// | TestFlight | staging server | `keys.testflight` |
    /// | App Store | production server | `keys.production` |
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // In your App's init or AppDelegate
    /// SwiftlyFeedback.configureAuto(keys: EnvironmentAPIKeys(
    ///     debug: "sf_dev_...",          // Optional: development API
    ///     testflight: "sf_staging_...", // Required
    ///     production: "sf_prod_..."     // Required
    /// ))
    /// ```
    ///
    /// - Parameter keys: Environment-specific API keys configuration.
    ///
    /// - Note: For security, consider storing API keys in your app's
    ///   Info.plist or using a secrets management solution rather than
    ///   hardcoding them in source code.
    public static func configureAuto(keys: EnvironmentAPIKeys) {
        Task {
            await BuildEnvironment.prepare()

            let apiKey = keys.currentKey
            let baseURL = keys.currentServerURL

            configure(with: apiKey, baseURL: baseURL)

            SDKLogger.info("Auto-configured for \(keys.currentEnvironmentName)")

            #if DEBUG
            if keys.debug != nil {
                SDKLogger.debug("Using dedicated DEBUG API key")
            } else {
                SDKLogger.debug("Using TestFlight API key (no DEBUG key provided)")
            }
            #endif
        }
    }

    /// Configure the SDK with automatic server detection based on build type.
    ///
    /// The server URL is automatically selected based on your build configuration:
    /// - DEBUG builds → development API
    /// - TestFlight builds → staging server
    /// - App Store builds → production server
    ///
    /// Localhost is ``configure(environment:key:)`` with ``FeedbackEnvironment/local``,
    /// not this method.
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
        Task {
            await BuildEnvironment.prepare()

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
            let generated = await UserIdentifier.getOrCreateUserId()

            let instance = SwiftlyFeedback(
                apiKey: apiKey,
                userId: generated,
                baseURL: baseURL
            )
            // Publishing and taking the pending custom id happen in one main-actor turn, so
            // `updateUser(customID:)` cannot observe a live client that still has the anonymous id.
            let pending = await MainActor.run { () -> String? in
                current = instance
                return PendingUserID.take()
            }
            if let pending {
                await instance.client.updateUserId(pending)
            }

            await instance.registerUser()
        }
    }

    /// Detect the appropriate server URL based on build environment
    private static func detectServerURL() -> URL {
        #if DEBUG
        // DEBUG builds → dev server
        return URL(string: "https://api.dev.getfeedbackkit.com/api/v1")!
        #else
        if BuildEnvironment.isTestFlight {
            // TestFlight builds → staging
            return URL(string: "https://api.testflight.getfeedbackkit.com/api/v1")!
        } else {
            // App Store builds → production
            return URL(string: "https://api.prod.getfeedbackkit.com/api/v1")!
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
            guard let instance = await configuredClient() else { return }
            await instance.updateMRR(payment.mrr)
        }
    }

    /// Clear the user's payment information (e.g., when subscription is cancelled).
    public static func clearUserPayment() {
        Task {
            guard let instance = await configuredClient() else { return }
            await instance.updateMRR(nil)
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
        Task { await applyCustomUserID(customID) }
    }

    /// Stores `customID` and, when a client is already live, sends it on the next request.
    ///
    /// A blank id is ignored. When configuration has not published `current` yet, the id
    /// stays in ``PendingUserID`` and in the user-id store; `configure` applies it when the
    /// client comes online instead of registering the anonymous id.
    static func applyCustomUserID(_ customID: String) async {
        let trimmed = customID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserIdentifier.setCustomUserId(trimmed)
        await MainActor.run { PendingUserID.store(trimmed) }
        guard let instance = await configuredClient() else { return }
        await instance.client.updateUserId(trimmed)
        await MainActor.run { _ = PendingUserID.take() }
        await instance.registerUser()
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

    /// The facade's designated initializer.
    ///
    /// `internal` rather than `private`, and carrying the same `session` seam `APIClient`
    /// already exposes, so a test can drive the REAL facade — its query building included —
    /// without touching the process-global state `configure(with:)` mutates. No public API
    /// changes: `configure` remains the only way in from outside the package.
    internal init(apiKey: String, userId: String, baseURL: URL, session: URLSession = .shared) {
        self.client = APIClient(baseURL: baseURL, apiKey: apiKey, userId: userId, session: session)
    }

    // MARK: - User Registration

    private func registerUser() async {
        await updateUserOnServer(mrr: storedMRR.withLock { $0 })
    }

    private func updateMRR(_ mrr: Double?) async {
        storedMRR.withLock { $0 = mrr }
        await updateUserOnServer(mrr: mrr)
    }

    private func updateUserOnServer(mrr: Double?) async {
        do {
            let _: RegisterUserResponse = try await client.postUsingUserId(path: "users/register") { userId in
                RegisterUserRequest(userId: userId, mrr: mrr)
            }
        } catch {
            // Silently fail - user registration is not critical. The error value can carry
            // a server message, so the log names the type only.
            SDKLogger.error("Failed to register user: \(String(describing: type(of: error)))")
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
        // Built as query ITEMS, never as a joined string appended to the path. Before this
        // moved onto `URLComponents`, every non-nil filter produced a request whose `?` was
        // percent-escaped into the path — the route did not exist, the server answered 404,
        // and the SDK surfaced `.notFound`. The unfiltered default appends nothing, which is
        // why the defect survived. See `APIClient.makeURL(baseURL:path:queryItems:)`.
        var queryItems: [URLQueryItem] = []

        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status.rawValue))
        }
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category.rawValue))
        }

        return try await client.get(path: "feedbacks", queryItems: queryItems)
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
    ///   - subscribeToMailingList: Whether the user consents to join the project's mailing list
    ///   - mailingListEmailTypes: Email preference types (e.g. `["operational", "marketing"]`). Defaults to both when nil.
    /// - Returns: The created feedback item
    public func submitFeedback(
        title: String,
        description: String,
        category: FeedbackCategory,
        email: String? = nil,
        subscribeToMailingList: Bool? = nil,
        mailingListEmailTypes: [String]? = nil
    ) async throws -> Feedback {
        try await client.postUsingUserId(path: "feedbacks") { userId in
            CreateFeedbackRequest(
                title: title,
                description: description,
                category: category,
                userId: userId,
                userEmail: email,
                subscribeToMailingList: email != nil ? subscribeToMailingList : nil,
                mailingListEmailTypes: email != nil && subscribeToMailingList == true ? mailingListEmailTypes : nil
            )
        }
    }

    // MARK: - Voting

    /// Vote for a feedback item with optional email for status notifications.
    ///
    /// - Parameters:
    ///   - feedbackId: The ID of the feedback to vote for
    ///   - email: Optional email to receive status change notifications
    ///   - notifyStatusChange: Whether to receive notifications when status changes (requires email)
    ///   - subscribeToMailingList: Whether the user consents to join the project's mailing list
    ///   - mailingListEmailTypes: Email preference types (e.g. `["operational", "marketing"]`). Defaults to both when nil.
    /// - Returns: Updated vote information
    public func vote(
        for feedbackId: UUID,
        email: String? = nil,
        notifyStatusChange: Bool = false,
        subscribeToMailingList: Bool? = nil,
        mailingListEmailTypes: [String]? = nil
    ) async throws -> VoteResult {
        try await client.postUsingUserId(path: "feedbacks/\(feedbackId)/votes") { userId in
            VoteRequest(
                userId: userId,
                email: email,
                notifyStatusChange: email != nil ? notifyStatusChange : false,
                subscribeToMailingList: email != nil ? subscribeToMailingList : nil,
                mailingListEmailTypes: email != nil && subscribeToMailingList == true ? mailingListEmailTypes : nil
            )
        }
    }

    /// Remove vote from a feedback item.
    ///
    /// - Parameter feedbackId: The ID of the feedback to unvote
    /// - Returns: Updated vote information
    public func unvote(for feedbackId: UUID) async throws -> VoteResult {
        try await client.deleteUsingUserId(path: "feedbacks/\(feedbackId)/votes") { userId in
            VoteRequest(
                userId: userId,
                email: nil,
                notifyStatusChange: nil,
                subscribeToMailingList: nil,
                mailingListEmailTypes: nil
            )
        }
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
        try await client.postUsingUserId(path: "feedbacks/\(feedbackId)/comments") { userId in
            CreateCommentRequest(content: content, userId: userId, isAdmin: nil)
        }
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
            guard let instance = await configuredClient() else { return }
            await instance.trackView(name: name, properties: properties)
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

    /// Records one event and returns the server's row.
    ///
    /// ``view(_:properties:)`` still swallows transport failures, because a missed
    /// impression must not surface in the host UI. A load test needs the error:
    /// a 429 is a result, not something to drop on the floor.
    public func recordEvent(
        name: String,
        properties: [String: String]? = nil
    ) async throws -> ViewEventResponse {
        try await client.postUsingUserId(path: "events/track") { userId in
            TrackViewEventRequest(eventName: name, userId: userId, properties: properties)
        }
    }

    /// Internal method to track a view event.
    internal func trackView(name: String, properties: [String: String]?) async {
        do {
            _ = try await recordEvent(name: name, properties: properties)
        } catch {
            // Silently fail - view tracking is not critical. Log the type, not the value.
            SDKLogger.error("Failed to track view: \(String(describing: type(of: error)))")
        }
    }

    // MARK: - Metrics

    /// Aggregate totals over one window.
    ///
    /// ```swift
    /// let summary = try await sf.metricsSummary(
    ///     measures: [.feedbackCount, .eventCount],
    ///     days: 30
    /// )
    /// let feedback = summary[.feedbackCount] ?? 0
    /// ```
    ///
    /// - Parameters:
    ///   - measures: The measures to report. Sent as one comma-joined value.
    ///   - dateFrom: Inclusive window start. Mutually exclusive with `days`.
    ///   - dateTo: Inclusive window end. Mutually exclusive with `days`.
    ///   - days: A trailing window, in days. Mutually exclusive with the date pair.
    ///   - status: Restrict to these feedback statuses. Sent as one comma-joined value.
    ///   - category: Restrict to these categories. Sent as one comma-joined value.
    ///   - eventName: Restrict to one event name. A single value, never a list.
    /// - Returns: The aggregate row, plus the `meta` block describing the window actually
    ///   applied — read ``MetricsMeta/retentionWindowDays`` rather than assuming one.
    public func metricsSummary(
        measures: [MetricMeasure],
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        days: Int? = nil,
        status: [FeedbackStatus]? = nil,
        category: [FeedbackCategory]? = nil,
        eventName: String? = nil
    ) async throws -> MetricSummary {
        let items = try Self.metricsQueryItems(
            measures: measures,
            dateFrom: dateFrom,
            dateTo: dateTo,
            days: days,
            status: status,
            category: category,
            eventName: eventName
        )
        return try await metricsGet(path: "metrics/summary", measures: measures, queryItems: items)
    }

    /// Bucketed totals over one window.
    ///
    /// Empty buckets are **present and zero-valued**, so `series.isEmpty` never stands in
    /// for "no activity".
    ///
    /// - Parameter granularity: The bucket width. Omitted, the server resolves its default.
    public func metricsTimeseries(
        measures: [MetricMeasure],
        granularity: MetricGranularity? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        days: Int? = nil,
        status: [FeedbackStatus]? = nil,
        category: [FeedbackCategory]? = nil,
        eventName: String? = nil
    ) async throws -> MetricSeries {
        let items = try Self.metricsQueryItems(
            measures: measures,
            granularity: granularity,
            dateFrom: dateFrom,
            dateTo: dateTo,
            days: days,
            status: status,
            category: category,
            eventName: eventName
        )
        return try await metricsGet(path: "metrics/timeseries", measures: measures, queryItems: items)
    }

    /// Totals grouped by one dimension, ordered by the first measure descending.
    ///
    /// Breaking down by ``MetricDimension/eventName`` is Pro-only and answers
    /// ``SwiftlyFeedbackError/tierUpgradeRequired(code:message:)`` below that plan.
    ///
    /// - Parameter granularity: Echoed back in `meta` and otherwise inert on this
    ///   operation, but still validated — an unparseable value is a 400.
    public func metricsBreakdown(
        measures: [MetricMeasure],
        dimension: MetricDimension,
        granularity: MetricGranularity? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        days: Int? = nil,
        status: [FeedbackStatus]? = nil,
        category: [FeedbackCategory]? = nil,
        eventName: String? = nil
    ) async throws -> MetricBreakdown {
        let items = try Self.metricsQueryItems(
            measures: measures,
            granularity: granularity,
            dimension: dimension,
            dateFrom: dateFrom,
            dateTo: dateTo,
            days: days,
            status: status,
            category: category,
            eventName: eventName
        )
        return try await metricsGet(path: "metrics/breakdown", measures: measures, queryItems: items)
    }

    /// One page of the raw event feed. Pro-only.
    ///
    /// When paging a live feed, pass an explicit `dateTo` so the window is stable across
    /// pages and advance it yourself; without one, events arriving mid-page shift the
    /// offsets and rows are double-counted.
    ///
    /// - Parameter perPage: Clamped locally to `1...200`. The clamp is a convenience, not a
    ///   contract — the server answers an out-of-range value with a 400, never a clamp.
    public func metricsEvents(
        eventName: String? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        days: Int? = nil,
        page: Int? = nil,
        perPage: Int? = nil
    ) async throws -> MetricEventList {
        let items = try Self.metricsQueryItems(
            measures: [],
            dateFrom: dateFrom,
            dateTo: dateTo,
            days: days,
            status: nil,
            category: nil,
            eventName: eventName,
            page: page,
            perPage: perPage
        )
        return try await metricsGet(path: "metrics/events", measures: [], queryItems: items)
    }

    /// The one place a metrics request is issued and logged.
    ///
    /// `T` is `Sendable` so its `Decodable` witness is nonisolated. `APIClient` is an actor;
    /// a plain `T: Decodable` constraint lets an isolated conformance cross that boundary
    /// (`#IsolatedConformances` at the `client.get` call).
    ///
    /// ⚠️ The log line carries the path and the measure list only. An `event_name` is
    /// customer data and a status or category filter is a customer's own segmentation;
    /// neither is logged, and the API key never is. `SDKLogger` takes a plain `String` —
    /// there is no `privacy:` argument to reach for here.
    private func metricsGet<T: Decodable & Sendable>(
        path: String,
        measures: [MetricMeasure],
        queryItems: [URLQueryItem]
    ) async throws -> T {
        SDKLogger.debug("Metrics request \(path) measures=[\(measures.map(\.rawValue).joined(separator: ","))]")
        do {
            return try await client.get(path: path, queryItems: queryItems)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            SDKLogger.error("Metrics request \(path) failed: \(String(describing: type(of: error)))")
            throw error
        }
    }

    /// Builds the wire query for every metrics operation.
    ///
    /// The key spellings are C2's, verbatim: there is no camelCase conversion anywhere on
    /// the query side of this SDK, so a `dateFrom` key would simply be ignored at 200.
    ///
    /// Three refusals happen here rather than over the network, because the server's answer
    /// to each is a 400 the caller could have known about locally.
    static func metricsQueryItems(
        measures: [MetricMeasure],
        granularity: MetricGranularity? = nil,
        dimension: MetricDimension? = nil,
        dateFrom: Date?,
        dateTo: Date?,
        days: Int?,
        status: [FeedbackStatus]?,
        category: [FeedbackCategory]?,
        eventName: String?,
        page: Int? = nil,
        perPage: Int? = nil
    ) throws -> [URLQueryItem] {
        if days != nil, dateFrom != nil || dateTo != nil {
            throw SwiftlyFeedbackError.badRequest(
                message: "days is mutually exclusive with date_from / date_to"
            )
        }
        if let dateFrom, let dateTo, dateFrom > dateTo {
            throw SwiftlyFeedbackError.badRequest(message: "date_from is later than date_to")
        }

        var items: [URLQueryItem] = []

        // One comma-joined value each — never repeated parameters.
        if !measures.isEmpty {
            items.append(URLQueryItem(
                name: "measures",
                value: measures.map(\.rawValue).joined(separator: ",")
            ))
        }
        if let granularity {
            items.append(URLQueryItem(name: "granularity", value: granularity.rawValue))
        }
        if let dimension {
            items.append(URLQueryItem(name: "dimension", value: dimension.rawValue))
        }
        if let status, !status.isEmpty {
            items.append(URLQueryItem(
                name: "status",
                value: status.map(\.rawValue).joined(separator: ",")
            ))
        }
        if let category, !category.isEmpty {
            items.append(URLQueryItem(
                name: "category",
                value: category.map(\.rawValue).joined(separator: ",")
            ))
        }
        // A single value, never a list, and free-form customer input — this is the value the
        // percent-encoding fix exists for.
        if let eventName {
            items.append(URLQueryItem(name: "event_name", value: eventName))
        }
        // 🔴 ISO-8601 INSTANTS, not `yyyy-MM-dd`. A day-granularity formatter here shifts the
        // window silently and the server answers 200 to the shifted question.
        if let dateFrom {
            items.append(URLQueryItem(name: "date_from", value: metricsInstant(dateFrom)))
        }
        if let dateTo {
            items.append(URLQueryItem(name: "date_to", value: metricsInstant(dateTo)))
        }
        if let days {
            items.append(URLQueryItem(name: "days", value: String(days)))
        }
        if let page {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if let perPage {
            items.append(URLQueryItem(name: "per_page", value: String(min(max(perPage, 1), 200))))
        }

        return items
    }

    /// One formatter per instant. `ISO8601DateFormatter` keeps mutable parse state, so a
    /// stored copy is not safe when a load test formats many windows at once.
    static func metricsInstant(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

/// A custom id saved before `configure` publishes `current`.
///
/// Main-actor isolated so storing it and publishing the client cannot interleave.
@MainActor
enum PendingUserID {
    static var value: String?

    static func store(_ id: String) {
        value = id
    }

    static func take() -> String? {
        let id = value
        value = nil
        return id
    }
}

// MARK: - Request Models

private struct CreateFeedbackRequest: Encodable, Sendable {
    let title: String
    let description: String
    let category: FeedbackCategory
    let userId: String
    let userEmail: String?
    let subscribeToMailingList: Bool?
    let mailingListEmailTypes: [String]?
}

private struct VoteRequest: Encodable, Sendable {
    let userId: String
    let email: String?
    let notifyStatusChange: Bool?
    let subscribeToMailingList: Bool?
    let mailingListEmailTypes: [String]?
}

private struct CreateCommentRequest: Encodable, Sendable {
    let content: String
    let userId: String
    let isAdmin: Bool?
}

private struct RegisterUserRequest: Encodable, Sendable {
    let userId: String
    let mrr: Double?
}

private struct RegisterUserResponse: Decodable, Sendable {
    let userId: String
    let mrr: Double?
}

private struct TrackViewEventRequest: Encodable, Sendable {
    let eventName: String
    let userId: String
    let properties: [String: String]?
}
