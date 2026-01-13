import Foundation

actor AdminAPIClient {
    static let shared = AdminAPIClient()

    private var baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        // Fallback to localhost initially
        self.baseURL = URL(string: "http://localhost:8080/api/v1")!
        self.session = URLSession.shared

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // Update base URL when server environment changes
    @MainActor
    func updateBaseURL() async {
        if let apiURL = URL(string: AppConfiguration.apiV1URL) {
            await self.setBaseURL(apiURL)
            AppLogger.api.info("AdminAPIClient baseURL updated to: \(apiURL.absoluteString)")
        }
    }

    // Initialize base URL from main actor context
    @MainActor
    func initializeBaseURL() async {
        if let apiURL = URL(string: AppConfiguration.apiV1URL) {
            await self.setBaseURL(apiURL)
            AppLogger.api.info("AdminAPIClient initialized with baseURL: \(apiURL.absoluteString)")
        }
    }

    private func setBaseURL(_ url: URL) {
        self.baseURL = url
    }

    // Test connectivity to server (uses root /health endpoint, not /api/v1/health)
    func testConnection() async throws -> Bool {
        // Health endpoint is at root level: http://host:port/health (not /api/v1/health)
        // baseURL is like http://localhost:8080/api/v1, we need http://localhost:8080/health
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/health"
        let healthURL = components.url!

        var request = URLRequest(url: healthURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            throw error
        }
    }

    private func makeRequest(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = true
    ) async throws -> (Data, URLResponse) {
        // Handle paths with query parameters - don't use appendingPathComponent for those
        let url: URL
        if path.contains("?") {
            // Path contains query string - append directly to avoid encoding ? as %3F
            url = URL(string: baseURL.absoluteString + "/" + path)!
        } else {
            url = baseURL.appendingPathComponent(path)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        AppLogger.api.info("📤 Request: \(method) \(url.absoluteString)")

        if requiresAuth {
            guard let token = await MainActor.run(body: { SecureStorageManager.shared.authToken }) else {
                AppLogger.api.error("❌ No auth token found in keychain")
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            AppLogger.api.debug("🔑 Auth token attached (length: \(token.count))")
        }

        if let body = body {
            do {
                let bodyData = try encoder.encode(body)
                request.httpBody = bodyData
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    AppLogger.api.debug("📦 Request body: \(bodyString)")
                }
            } catch {
                AppLogger.api.error("❌ Failed to encode request body: \(error.localizedDescription)")
                throw error
            }
        }

        do {
            AppLogger.api.info("🌐 Sending request to \(url.absoluteString)...")
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.api.info("📥 Response: \(httpResponse.statusCode) for \(method) \(path)")

                if let responseString = String(data: data, encoding: .utf8) {
                    if data.count < 1000 {
                        AppLogger.api.debug("📄 Response body: \(responseString)")
                    } else {
                        AppLogger.api.debug("📄 Response body (truncated): \(responseString.prefix(500))...")
                    }
                }
            }

            return (data, response)
        } catch let error as URLError {
            AppLogger.api.error("❌ URLError: \(error.code.rawValue) - \(error.localizedDescription)")
            AppLogger.api.error("❌ URLError details - code: \(error.code.rawValue), failingURL: \(error.failingURL?.absoluteString ?? "nil")")
            throw APIError.networkError(error)
        } catch {
            AppLogger.api.error("❌ Network error: \(error.localizedDescription)")
            AppLogger.api.error("❌ Error type: \(type(of: error))")
            throw APIError.networkError(error)
        }
    }

    func get<T: Decodable>(path: String, requiresAuth: Bool = true) async throws -> T {
        AppLogger.api.info("🔵 GET \(path)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws -> T {
        AppLogger.api.info("🟢 POST \(path) (with body)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func post(path: String, requiresAuth: Bool = true) async throws {
        AppLogger.api.info("🟢 POST \(path) (no body, no response)")
        let (data, response) = try await makeRequest(path: path, method: "POST", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        AppLogger.api.info("✅ POST \(path) - completed")
    }

    func post<T: Decodable>(path: String, requiresAuth: Bool = true) async throws -> T {
        AppLogger.api.info("🟢 POST \(path) (no body, with response)")
        let (data, response) = try await makeRequest(path: path, method: "POST", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func patch<T: Decodable, B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws -> T {
        AppLogger.api.info("🟠 PATCH \(path)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func put<B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws {
        AppLogger.api.info("🟡 PUT \(path)")
        let (data, response) = try await makeRequest(path: path, method: "PUT", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        AppLogger.api.info("✅ PUT \(path) - completed")
    }

    func delete(path: String, requiresAuth: Bool = true) async throws {
        AppLogger.api.info("🔴 DELETE \(path)")
        let (data, response) = try await makeRequest(path: path, method: "DELETE", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        AppLogger.api.info("✅ DELETE \(path) - completed")
    }

    func delete<B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws {
        AppLogger.api.info("🔴 DELETE \(path) (with body)")
        let (data, response) = try await makeRequest(path: path, method: "DELETE", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        AppLogger.api.info("✅ DELETE \(path) - completed")
    }

    // MARK: - Feedback API (uses X-API-Key)

    func getFeedbacks(apiKey: String, status: FeedbackStatus? = nil, category: FeedbackCategory? = nil) async throws -> [Feedback] {
        var path = "feedbacks"
        var queryParams: [String] = []

        if let status = status {
            queryParams.append("status=\(status.rawValue)")
        }
        if let category = category {
            queryParams.append("category=\(category.rawValue)")
        }

        if !queryParams.isEmpty {
            path += "?" + queryParams.joined(separator: "&")
        }

        AppLogger.api.info("🔵 GET \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "GET", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([Feedback].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) feedbacks")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getFeedback(id: UUID, apiKey: String) async throws -> Feedback {
        let path = "feedbacks/\(id)"
        AppLogger.api.info("🔵 GET \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "GET", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Feedback.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getComments(feedbackId: UUID, apiKey: String) async throws -> [Comment] {
        let path = "feedbacks/\(feedbackId)/comments"
        AppLogger.api.info("🔵 GET \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "GET", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([Comment].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) comments")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createComment(feedbackId: UUID, content: String, userId: String, isAdmin: Bool, apiKey: String) async throws -> Comment {
        let path = "feedbacks/\(feedbackId)/comments"
        let body = CreateCommentRequest(content: content, userId: userId, isAdmin: isAdmin)

        AppLogger.api.info("🟢 POST \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "POST", body: body, apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Comment.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func deleteComment(feedbackId: UUID, commentId: UUID, apiKey: String) async throws {
        let path = "feedbacks/\(feedbackId)/comments/\(commentId)"
        AppLogger.api.info("🔴 DELETE \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "DELETE", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)
        AppLogger.api.info("✅ DELETE \(path) - completed")
    }

    func createFeedback(
        title: String,
        description: String,
        category: FeedbackCategory,
        userId: String,
        userEmail: String?,
        apiKey: String
    ) async throws -> Feedback {
        let path = "feedbacks"
        let body = CreateFeedbackRequest(
            title: title,
            description: description,
            category: category,
            userId: userId,
            userEmail: userEmail
        )

        AppLogger.api.info("🟢 POST \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "POST", body: body, apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Feedback.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    private func makeRequestWithApiKey(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        apiKey: String
    ) async throws -> (Data, URLResponse) {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        AppLogger.api.info("📤 Request: \(method) \(url.absoluteString) (API key)")

        if let body = body {
            do {
                let bodyData = try encoder.encode(body)
                request.httpBody = bodyData
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    AppLogger.api.debug("📦 Request body: \(bodyString)")
                }
            } catch {
                AppLogger.api.error("❌ Failed to encode request body: \(error.localizedDescription)")
                throw error
            }
        }

        do {
            AppLogger.api.info("🌐 Sending request to \(url.absoluteString)...")
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                AppLogger.api.info("📥 Response: \(httpResponse.statusCode) for \(method) \(path)")

                if let responseString = String(data: data, encoding: .utf8) {
                    if data.count < 1000 {
                        AppLogger.api.debug("📄 Response body: \(responseString)")
                    } else {
                        AppLogger.api.debug("📄 Response body (truncated): \(responseString.prefix(500))...")
                    }
                }
            }

            return (data, response)
        } catch let error as URLError {
            AppLogger.api.error("❌ URLError: \(error.code.rawValue) - \(error.localizedDescription)")
            throw APIError.networkError(error)
        } catch {
            AppLogger.api.error("❌ Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data, path: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            AppLogger.api.error("❌ \(path) - Invalid response (not HTTPURLResponse)")
            throw APIError.invalidResponse
        }

        let statusCode = httpResponse.statusCode
        AppLogger.api.info("🔍 Validating response for \(path): status \(statusCode)")

        switch statusCode {
        case 200...299:
            AppLogger.api.debug("✅ \(path) - Status \(statusCode) OK")
            return
        case 401:
            AppLogger.api.error("❌ \(path) - 401 Unauthorized")
            throw APIError.unauthorized
        case 402:
            let message = parseErrorMessage(data)
            AppLogger.api.error("❌ \(path) - 402 Payment Required: \(message)")
            throw APIError.paymentRequired(message)
        case 403:
            let message = parseErrorMessage(data)
            AppLogger.api.error("❌ \(path) - 403 Forbidden: \(message)")
            throw APIError.forbidden(message)
        case 404:
            let message = parseErrorMessage(data)
            AppLogger.api.error("❌ \(path) - 404 Not Found: \(message)")
            throw APIError.notFound(message)
        case 409:
            let message = parseErrorMessage(data)
            AppLogger.api.error("❌ \(path) - 409 Conflict: \(message)")
            throw APIError.conflict(message)
        case 400:
            let message = parseErrorMessage(data)
            AppLogger.api.error("❌ \(path) - 400 Bad Request: \(message)")
            throw APIError.badRequest(message)
        default:
            let message = parseErrorMessage(data)
            AppLogger.api.error("❌ \(path) - \(statusCode) Server Error: \(message)")
            throw APIError.serverError(statusCode, message)
        }
    }

    private func parseErrorMessage(_ data: Data) -> String {
        struct ErrorResponse: Decodable {
            let reason: String?
            let error: Bool?
        }
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            return errorResponse.reason ?? "Unknown error"
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }

    // MARK: - SDK Users API

    func getSDKUsers(projectId: UUID) async throws -> [SDKUser] {
        let path = "users/project/\(projectId)"
        AppLogger.api.info("🔵 GET \(path) (SDK users)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 SDK Users - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.debug("📊 SDK Users - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode([SDKUser].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) SDK users")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getAllSDKUsers() async throws -> [SDKUser] {
        let path = "users/all"
        AppLogger.api.info("🔵 GET \(path) (all SDK users)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 All SDK Users - attempting to decode \(data.count) bytes")
            let decoded = try decoder.decode([SDKUser].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) SDK users")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getAllSDKUserStats() async throws -> SDKUserStats {
        let path = "users/all/stats"
        AppLogger.api.info("🔵 GET \(path) (all SDK user stats)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 All SDK User Stats - attempting to decode \(data.count) bytes")
            let decoded = try decoder.decode(SDKUserStats.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded SDK user stats: totalUsers=\(decoded.totalUsers), totalMrr=\(decoded.totalMrr)")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getSDKUserStats(projectId: UUID) async throws -> SDKUserStats {
        let path = "users/project/\(projectId)/stats"
        AppLogger.api.info("🔵 GET \(path) (SDK user stats)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 SDK User Stats - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.debug("📊 SDK User Stats - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode(SDKUserStats.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded SDK user stats: totalUsers=\(decoded.totalUsers), totalMrr=\(decoded.totalMrr)")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - View Events API

    func getAllViewEventStats(days: Int = 30) async throws -> ViewEventsOverview {
        let path = "events/all/stats?days=\(days)"
        AppLogger.api.info("🔵 GET \(path) (all view event stats, \(days) days)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 All View Event Stats - attempting to decode \(data.count) bytes")
            let decoded = try decoder.decode(ViewEventsOverview.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded view event stats: totalEvents=\(decoded.totalEvents), uniqueUsers=\(decoded.uniqueUsers)")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getViewEventStats(projectId: UUID, days: Int = 30) async throws -> ViewEventsOverview {
        let path = "events/project/\(projectId)/stats?days=\(days)"
        AppLogger.api.info("🔵 GET \(path) (view event stats, \(days) days)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 View Event Stats - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.debug("📊 View Event Stats - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode(ViewEventsOverview.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded view event stats: totalEvents=\(decoded.totalEvents), uniqueUsers=\(decoded.uniqueUsers)")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getViewEvents(projectId: UUID) async throws -> [ViewEvent] {
        let path = "events/project/\(projectId)"
        AppLogger.api.info("🔵 GET \(path) (view events)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 View Events - attempting to decode \(data.count) bytes")
            let decoded = try decoder.decode([ViewEvent].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) view events")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Notification Settings API

    func updateNotificationSettings(notifyNewFeedback: Bool?, notifyNewComments: Bool?) async throws -> User {
        let path = "auth/notifications"
        let body = UpdateNotificationSettingsRequest(
            notifyNewFeedback: notifyNewFeedback,
            notifyNewComments: notifyNewComments
        )

        AppLogger.api.info("🟠 PATCH \(path) (notification settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(User.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func overrideSubscriptionTier(_ tier: SubscriptionTier) async throws -> SubscriptionInfoDTO {
        let path = "auth/subscription/tier"
        let body = OverrideSubscriptionTierRequest(tier: tier.rawValue)

        AppLogger.api.info("🟠 PATCH \(path) (subscription tier override)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(SubscriptionInfoDTO.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - tier updated to: \(decoded.tier)")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Project Slack Settings API

    func updateProjectSlackSettings(
        projectId: UUID,
        slackWebhookUrl: String?,
        slackNotifyNewFeedback: Bool?,
        slackNotifyNewComments: Bool?,
        slackNotifyStatusChanges: Bool?,
        slackIsActive: Bool?
    ) async throws -> Project {
        let path = "projects/\(projectId)/slack"
        let body = UpdateProjectSlackRequest(
            slackWebhookUrl: slackWebhookUrl,
            slackNotifyNewFeedback: slackNotifyNewFeedback,
            slackNotifyNewComments: slackNotifyNewComments,
            slackNotifyStatusChanges: slackNotifyStatusChanges,
            slackIsActive: slackIsActive
        )

        AppLogger.api.info("🟠 PATCH \(path) (slack settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Project Status Settings API

    func updateProjectAllowedStatuses(
        projectId: UUID,
        allowedStatuses: [String]
    ) async throws -> Project {
        let path = "projects/\(projectId)/statuses"
        let body = UpdateProjectStatusesRequest(allowedStatuses: allowedStatuses)

        AppLogger.api.info("🟠 PATCH \(path) (allowed statuses)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - GitHub Integration API

    func updateProjectGitHubSettings(
        projectId: UUID,
        githubOwner: String?,
        githubRepo: String?,
        githubToken: String?,
        githubDefaultLabels: [String]?,
        githubSyncStatus: Bool?,
        githubIsActive: Bool?
    ) async throws -> Project {
        let path = "projects/\(projectId)/github"
        let body = UpdateProjectGitHubRequest(
            githubOwner: githubOwner,
            githubRepo: githubRepo,
            githubToken: githubToken,
            githubDefaultLabels: githubDefaultLabels,
            githubSyncStatus: githubSyncStatus,
            githubIsActive: githubIsActive
        )

        AppLogger.api.info("🟠 PATCH \(path) (GitHub settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createGitHubIssue(
        projectId: UUID,
        feedbackId: UUID,
        additionalLabels: [String]? = nil
    ) async throws -> CreateGitHubIssueResponse {
        let path = "projects/\(projectId)/github/issue"
        let body = CreateGitHubIssueRequest(
            feedbackId: feedbackId,
            additionalLabels: additionalLabels
        )

        AppLogger.api.info("🟢 POST \(path) (create GitHub issue)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(CreateGitHubIssueResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func bulkCreateGitHubIssues(
        projectId: UUID,
        feedbackIds: [UUID],
        additionalLabels: [String]? = nil
    ) async throws -> BulkCreateGitHubIssuesResponse {
        let path = "projects/\(projectId)/github/issues"
        let body = BulkCreateGitHubIssuesRequest(
            feedbackIds: feedbackIds,
            additionalLabels: additionalLabels
        )

        AppLogger.api.info("🟢 POST \(path) (bulk create GitHub issues)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(BulkCreateGitHubIssuesResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded: \(decoded.created.count) created, \(decoded.failed.count) failed")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - ClickUp Integration API

    func updateProjectClickUpSettings(
        projectId: UUID,
        clickupToken: String?,
        clickupListId: String?,
        clickupWorkspaceName: String?,
        clickupListName: String?,
        clickupDefaultTags: [String]?,
        clickupSyncStatus: Bool?,
        clickupSyncComments: Bool?,
        clickupVotesFieldId: String?,
        clickupIsActive: Bool?
    ) async throws -> Project {
        let path = "projects/\(projectId)/clickup"
        let body = UpdateProjectClickUpRequest(
            clickupToken: clickupToken,
            clickupListId: clickupListId,
            clickupWorkspaceName: clickupWorkspaceName,
            clickupListName: clickupListName,
            clickupDefaultTags: clickupDefaultTags,
            clickupSyncStatus: clickupSyncStatus,
            clickupSyncComments: clickupSyncComments,
            clickupVotesFieldId: clickupVotesFieldId,
            clickupIsActive: clickupIsActive
        )

        AppLogger.api.info("🟠 PATCH \(path) (ClickUp settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createClickUpTask(
        projectId: UUID,
        feedbackId: UUID,
        additionalTags: [String]? = nil
    ) async throws -> CreateClickUpTaskResponse {
        let path = "projects/\(projectId)/clickup/task"
        let body = CreateClickUpTaskRequest(
            feedbackId: feedbackId,
            additionalTags: additionalTags
        )

        AppLogger.api.info("🟢 POST \(path) (create ClickUp task)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(CreateClickUpTaskResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func bulkCreateClickUpTasks(
        projectId: UUID,
        feedbackIds: [UUID],
        additionalTags: [String]? = nil
    ) async throws -> BulkCreateClickUpTasksResponse {
        let path = "projects/\(projectId)/clickup/tasks"
        let body = BulkCreateClickUpTasksRequest(
            feedbackIds: feedbackIds,
            additionalTags: additionalTags
        )

        AppLogger.api.info("🟢 POST \(path) (bulk create ClickUp tasks)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(BulkCreateClickUpTasksResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded: \(decoded.created.count) created, \(decoded.failed.count) failed")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getClickUpWorkspaces(projectId: UUID) async throws -> [ClickUpWorkspace] {
        let path = "projects/\(projectId)/clickup/workspaces"
        AppLogger.api.info("🔵 GET \(path) (ClickUp workspaces)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([ClickUpWorkspace].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) workspaces")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getClickUpSpaces(projectId: UUID, workspaceId: String) async throws -> [ClickUpSpace] {
        let path = "projects/\(projectId)/clickup/spaces/\(workspaceId)"
        AppLogger.api.info("🔵 GET \(path) (ClickUp spaces)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([ClickUpSpace].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) spaces")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getClickUpFolders(projectId: UUID, spaceId: String) async throws -> [ClickUpFolder] {
        let path = "projects/\(projectId)/clickup/folders/\(spaceId)"
        AppLogger.api.info("🔵 GET \(path) (ClickUp folders)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([ClickUpFolder].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) folders")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getClickUpLists(projectId: UUID, folderId: String) async throws -> [ClickUpList] {
        let path = "projects/\(projectId)/clickup/lists/\(folderId)"
        AppLogger.api.info("🔵 GET \(path) (ClickUp lists)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([ClickUpList].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) lists")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getClickUpFolderlessLists(projectId: UUID, spaceId: String) async throws -> [ClickUpList] {
        let path = "projects/\(projectId)/clickup/folderless-lists/\(spaceId)"
        AppLogger.api.info("🔵 GET \(path) (ClickUp folderless lists)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([ClickUpList].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) lists")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getClickUpCustomFields(projectId: UUID) async throws -> [ClickUpCustomField] {
        let path = "projects/\(projectId)/clickup/custom-fields"
        AppLogger.api.info("🔵 GET \(path) (ClickUp custom fields)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([ClickUpCustomField].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) custom fields")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Notion Integration API

    func updateProjectNotionSettings(
        projectId: UUID,
        notionToken: String?,
        notionDatabaseId: String?,
        notionDatabaseName: String?,
        notionSyncStatus: Bool?,
        notionSyncComments: Bool?,
        notionStatusProperty: String?,
        notionVotesProperty: String?,
        notionIsActive: Bool?
    ) async throws -> Project {
        let path = "projects/\(projectId)/notion"
        let body = UpdateProjectNotionRequest(
            notionToken: notionToken,
            notionDatabaseId: notionDatabaseId,
            notionDatabaseName: notionDatabaseName,
            notionSyncStatus: notionSyncStatus,
            notionSyncComments: notionSyncComments,
            notionStatusProperty: notionStatusProperty,
            notionVotesProperty: notionVotesProperty,
            notionIsActive: notionIsActive
        )

        AppLogger.api.info("🟠 PATCH \(path) (Notion settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createNotionPage(
        projectId: UUID,
        feedbackId: UUID
    ) async throws -> CreateNotionPageResponse {
        let path = "projects/\(projectId)/notion/page"
        let body = CreateNotionPageRequest(feedbackId: feedbackId)

        AppLogger.api.info("🟢 POST \(path) (create Notion page)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(CreateNotionPageResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func bulkCreateNotionPages(
        projectId: UUID,
        feedbackIds: [UUID]
    ) async throws -> BulkCreateNotionPagesResponse {
        let path = "projects/\(projectId)/notion/pages"
        let body = BulkCreateNotionPagesRequest(feedbackIds: feedbackIds)

        AppLogger.api.info("🟢 POST \(path) (bulk create Notion pages)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(BulkCreateNotionPagesResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded: \(decoded.created.count) created, \(decoded.failed.count) failed")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getNotionDatabases(projectId: UUID) async throws -> [NotionDatabase] {
        let path = "projects/\(projectId)/notion/databases"
        AppLogger.api.info("🔵 GET \(path) (Notion databases)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([NotionDatabase].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) databases")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getNotionDatabaseProperties(projectId: UUID, databaseId: String) async throws -> NotionDatabase {
        let path = "projects/\(projectId)/notion/database/\(databaseId)/properties"
        AppLogger.api.info("🔵 GET \(path) (Notion database properties)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(NotionDatabase.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded database with \(decoded.properties.count) properties")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Monday.com Integration API

    func updateProjectMondaySettings(
        projectId: UUID,
        mondayToken: String?,
        mondayBoardId: String?,
        mondayBoardName: String?,
        mondayGroupId: String?,
        mondayGroupName: String?,
        mondaySyncStatus: Bool?,
        mondaySyncComments: Bool?,
        mondayStatusColumnId: String?,
        mondayVotesColumnId: String?,
        mondayIsActive: Bool?
    ) async throws -> Project {
        let path = "projects/\(projectId)/monday"
        let body = UpdateProjectMondayRequest(
            mondayToken: mondayToken,
            mondayBoardId: mondayBoardId,
            mondayBoardName: mondayBoardName,
            mondayGroupId: mondayGroupId,
            mondayGroupName: mondayGroupName,
            mondaySyncStatus: mondaySyncStatus,
            mondaySyncComments: mondaySyncComments,
            mondayStatusColumnId: mondayStatusColumnId,
            mondayVotesColumnId: mondayVotesColumnId,
            mondayIsActive: mondayIsActive
        )

        AppLogger.api.info("🟠 PATCH \(path) (Monday.com settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createMondayItem(
        projectId: UUID,
        feedbackId: UUID
    ) async throws -> CreateMondayItemResponse {
        let path = "projects/\(projectId)/monday/item"
        let body = CreateMondayItemRequest(feedbackId: feedbackId)

        AppLogger.api.info("🟢 POST \(path) (create Monday.com item)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(CreateMondayItemResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func bulkCreateMondayItems(
        projectId: UUID,
        feedbackIds: [UUID]
    ) async throws -> BulkCreateMondayItemsResponse {
        let path = "projects/\(projectId)/monday/items"
        let body = BulkCreateMondayItemsRequest(feedbackIds: feedbackIds)

        AppLogger.api.info("🟢 POST \(path) (bulk create Monday.com items)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(BulkCreateMondayItemsResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded: \(decoded.created.count) created, \(decoded.failed.count) failed")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getMondayBoards(projectId: UUID) async throws -> [MondayBoard] {
        let path = "projects/\(projectId)/monday/boards"
        AppLogger.api.info("🔵 GET \(path) (Monday.com boards)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([MondayBoard].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) boards")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getMondayGroups(projectId: UUID, boardId: String) async throws -> [MondayGroup] {
        let path = "projects/\(projectId)/monday/boards/\(boardId)/groups"
        AppLogger.api.info("🔵 GET \(path) (Monday.com groups)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([MondayGroup].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) groups")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getMondayColumns(projectId: UUID, boardId: String) async throws -> [MondayColumn] {
        let path = "projects/\(projectId)/monday/boards/\(boardId)/columns"
        AppLogger.api.info("🔵 GET \(path) (Monday.com columns)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([MondayColumn].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) columns")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Linear Integration API

    func updateLinearSettings(projectId: UUID, request: UpdateProjectLinearRequest) async throws -> Project {
        let path = "projects/\(projectId)/linear"
        let body = request

        AppLogger.api.info("🟠 PATCH \(path) (Linear settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createLinearIssue(
        projectId: UUID,
        feedbackId: UUID,
        additionalLabelIds: [String]? = nil
    ) async throws -> CreateLinearIssueResponse {
        let path = "projects/\(projectId)/linear/issue"
        let body = CreateLinearIssueRequest(
            feedbackId: feedbackId,
            additionalLabelIds: additionalLabelIds
        )

        AppLogger.api.info("🟢 POST \(path) (create Linear issue)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(CreateLinearIssueResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func bulkCreateLinearIssues(
        projectId: UUID,
        feedbackIds: [UUID],
        additionalLabelIds: [String]? = nil
    ) async throws -> BulkCreateLinearIssuesResponse {
        let path = "projects/\(projectId)/linear/issues"
        let body = BulkCreateLinearIssuesRequest(
            feedbackIds: feedbackIds,
            additionalLabelIds: additionalLabelIds
        )

        AppLogger.api.info("🟢 POST \(path) (bulk create Linear issues)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(BulkCreateLinearIssuesResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded: \(decoded.created.count) created, \(decoded.failed.count) failed")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getLinearTeams(projectId: UUID) async throws -> [LinearTeam] {
        let path = "projects/\(projectId)/linear/teams"
        AppLogger.api.info("🔵 GET \(path) (Linear teams)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([LinearTeam].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) teams")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getLinearProjects(projectId: UUID, teamId: String) async throws -> [LinearProject] {
        let path = "projects/\(projectId)/linear/projects/\(teamId)"
        AppLogger.api.info("🔵 GET \(path) (Linear projects)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([LinearProject].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) projects")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getLinearWorkflowStates(projectId: UUID, teamId: String) async throws -> [LinearWorkflowState] {
        let path = "projects/\(projectId)/linear/states/\(teamId)"
        AppLogger.api.info("🔵 GET \(path) (Linear workflow states)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([LinearWorkflowState].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) states")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getLinearLabels(projectId: UUID, teamId: String) async throws -> [LinearLabel] {
        let path = "projects/\(projectId)/linear/labels/\(teamId)"
        AppLogger.api.info("🔵 GET \(path) (Linear labels)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([LinearLabel].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) labels")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Trello Integration API

    func updateTrelloSettings(projectId: UUID, request: UpdateProjectTrelloRequest) async throws -> Project {
        let path = "projects/\(projectId)/trello"
        let body = request

        AppLogger.api.info("🟠 PATCH \(path) (Trello settings)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Project.self, from: data)
            AppLogger.api.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createTrelloCard(
        projectId: UUID,
        feedbackId: UUID
    ) async throws -> CreateTrelloCardResponse {
        let path = "projects/\(projectId)/trello/card"
        let body = CreateTrelloCardRequest(feedbackId: feedbackId)

        AppLogger.api.info("🟢 POST \(path) (create Trello card)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(CreateTrelloCardResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func bulkCreateTrelloCards(
        projectId: UUID,
        feedbackIds: [UUID]
    ) async throws -> BulkCreateTrelloCardsResponse {
        let path = "projects/\(projectId)/trello/cards"
        let body = BulkCreateTrelloCardsRequest(feedbackIds: feedbackIds)

        AppLogger.api.info("🟢 POST \(path) (bulk create Trello cards)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(BulkCreateTrelloCardsResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - decoded: \(decoded.created.count) created, \(decoded.failed.count) failed")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getTrelloBoards(projectId: UUID) async throws -> [TrelloBoard] {
        let path = "projects/\(projectId)/trello/boards"
        AppLogger.api.info("🔵 GET \(path) (Trello boards)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([TrelloBoard].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) boards")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getTrelloLists(projectId: UUID, boardId: String) async throws -> [TrelloList] {
        let path = "projects/\(projectId)/trello/boards/\(boardId)/lists"
        AppLogger.api.info("🔵 GET \(path) (Trello lists)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([TrelloList].self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded \(decoded.count) lists")
            return decoded
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Merge Feedback API

    func mergeFeedback(primaryId: UUID, secondaryIds: [UUID]) async throws -> MergeFeedbackResponse {
        let path = "feedbacks/merge"
        let body = MergeFeedbackRequest(primaryFeedbackId: primaryId, secondaryFeedbackIds: secondaryIds)

        AppLogger.api.info("🟢 POST \(path) (merge feedback)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(MergeFeedbackResponse.self, from: data)
            AppLogger.api.info("✅ POST \(path) - merged \(decoded.mergedCount) feedbacks")
            return decoded
        } catch {
            AppLogger.api.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Home Dashboard API

    func getHomeDashboard() async throws -> HomeDashboard {
        let path = "dashboard/home"
        AppLogger.api.info("🔵 GET \(path) (home dashboard)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            AppLogger.api.debug("📊 Home Dashboard - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.debug("📊 Home Dashboard - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode(HomeDashboard.self, from: data)
            AppLogger.api.info("✅ GET \(path) - decoded home dashboard: totalProjects=\(decoded.totalProjects), totalFeedback=\(decoded.totalFeedback)")
            return decoded
        } catch let decodingError as DecodingError {
            AppLogger.api.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                AppLogger.api.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            AppLogger.api.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Helpers

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Key '\(key.stringValue)' not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). \(context.debugDescription)"
        case .typeMismatch(let type, let context):
            return "Type mismatch for type \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). \(context.debugDescription)"
        case .valueNotFound(let type, let context):
            return "Value of type \(type) not found at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). \(context.debugDescription)"
        case .dataCorrupted(let context):
            return "Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: ".")). \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthorized
    case paymentRequired(String)
    case forbidden(String)
    case notFound(String)
    case conflict(String)
    case badRequest(String)
    case serverError(Int, String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Please log in to continue"
        case .paymentRequired(let message):
            return message
        case .forbidden(let message):
            return message
        case .notFound(let message):
            return message
        case .conflict(let message):
            return message
        case .badRequest(let message):
            return message
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }

    /// Whether this error is a payment required error (subscription limit reached)
    var isPaymentRequired: Bool {
        if case .paymentRequired = self { return true }
        return false
    }

    /// The error message for payment required errors
    var errorMessage: String {
        switch self {
        case .paymentRequired(let message):
            return message
        default:
            return errorDescription ?? "Unknown error"
        }
    }

    /// Determines the required subscription tier from a 402 error message
    var requiredSubscriptionTier: SubscriptionTier {
        guard isPaymentRequired else { return .pro }
        let message = errorMessage.lowercased()
        if message.contains("team") {
            return .team
        }
        return .pro
    }
}
