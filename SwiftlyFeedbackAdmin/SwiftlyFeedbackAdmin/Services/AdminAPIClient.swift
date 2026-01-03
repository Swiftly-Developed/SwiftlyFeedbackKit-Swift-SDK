import Foundation
import OSLog

private let logger = Logger(subsystem: "com.swiftlyfeedback.admin", category: "APIClient")

actor AdminAPIClient {
    static let shared = AdminAPIClient()

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        // Default to localhost for development
        self.baseURL = URL(string: "http://localhost:8080/api/v1")!
        self.session = URLSession.shared

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601

        logger.info("AdminAPIClient initialized with baseURL: \(self.baseURL.absoluteString)")
    }

    private func makeRequest(
        path: String,
        method: String,
        body: (any Encodable)? = nil,
        requiresAuth: Bool = true
    ) async throws -> (Data, URLResponse) {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        logger.info("📤 Request: \(method) \(url.absoluteString)")

        if requiresAuth {
            guard let token = KeychainService.getToken() else {
                logger.error("❌ No auth token found in keychain")
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            logger.debug("🔑 Auth token attached (length: \(token.count))")
        }

        if let body = body {
            do {
                let bodyData = try encoder.encode(body)
                request.httpBody = bodyData
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    logger.debug("📦 Request body: \(bodyString)")
                }
            } catch {
                logger.error("❌ Failed to encode request body: \(error.localizedDescription)")
                throw error
            }
        }

        do {
            logger.info("🌐 Sending request to \(url.absoluteString)...")
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                logger.info("📥 Response: \(httpResponse.statusCode) for \(method) \(path)")

                if let responseString = String(data: data, encoding: .utf8) {
                    if data.count < 1000 {
                        logger.debug("📄 Response body: \(responseString)")
                    } else {
                        logger.debug("📄 Response body (truncated): \(responseString.prefix(500))...")
                    }
                }
            }

            return (data, response)
        } catch let error as URLError {
            logger.error("❌ URLError: \(error.code.rawValue) - \(error.localizedDescription)")
            logger.error("❌ URLError details - code: \(error.code.rawValue), failingURL: \(error.failingURL?.absoluteString ?? "nil")")
            throw APIError.networkError(error)
        } catch {
            logger.error("❌ Network error: \(error.localizedDescription)")
            logger.error("❌ Error type: \(type(of: error))")
            throw APIError.networkError(error)
        }
    }

    func get<T: Decodable>(path: String, requiresAuth: Bool = true) async throws -> T {
        logger.info("🔵 GET \(path)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            logger.info("✅ GET \(path) - decoded successfully")
            return decoded
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws -> T {
        logger.info("🟢 POST \(path) (with body)")
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            logger.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            logger.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func post(path: String, requiresAuth: Bool = true) async throws {
        logger.info("🟢 POST \(path) (no body, no response)")
        let (data, response) = try await makeRequest(path: path, method: "POST", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        logger.info("✅ POST \(path) - completed")
    }

    func post<T: Decodable>(path: String, requiresAuth: Bool = true) async throws -> T {
        logger.info("🟢 POST \(path) (no body, with response)")
        let (data, response) = try await makeRequest(path: path, method: "POST", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            logger.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            logger.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func patch<T: Decodable, B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws -> T {
        logger.info("🟠 PATCH \(path)")
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        do {
            let decoded = try decoder.decode(T.self, from: data)
            logger.info("✅ PATCH \(path) - decoded successfully")
            return decoded
        } catch {
            logger.error("❌ PATCH \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func put<B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws {
        logger.info("🟡 PUT \(path)")
        let (data, response) = try await makeRequest(path: path, method: "PUT", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        logger.info("✅ PUT \(path) - completed")
    }

    func delete(path: String, requiresAuth: Bool = true) async throws {
        logger.info("🔴 DELETE \(path)")
        let (data, response) = try await makeRequest(path: path, method: "DELETE", requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        logger.info("✅ DELETE \(path) - completed")
    }

    func delete<B: Encodable>(path: String, body: B, requiresAuth: Bool = true) async throws {
        logger.info("🔴 DELETE \(path) (with body)")
        let (data, response) = try await makeRequest(path: path, method: "DELETE", body: body, requiresAuth: requiresAuth)
        try validateResponse(response, data: data, path: path)
        logger.info("✅ DELETE \(path) - completed")
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

        logger.info("🔵 GET \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "GET", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([Feedback].self, from: data)
            logger.info("✅ GET \(path) - decoded \(decoded.count) feedbacks")
            return decoded
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getFeedback(id: UUID, apiKey: String) async throws -> Feedback {
        let path = "feedbacks/\(id)"
        logger.info("🔵 GET \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "GET", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Feedback.self, from: data)
            logger.info("✅ GET \(path) - decoded successfully")
            return decoded
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getComments(feedbackId: UUID, apiKey: String) async throws -> [Comment] {
        let path = "feedbacks/\(feedbackId)/comments"
        logger.info("🔵 GET \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "GET", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode([Comment].self, from: data)
            logger.info("✅ GET \(path) - decoded \(decoded.count) comments")
            return decoded
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func createComment(feedbackId: UUID, content: String, userId: String, isAdmin: Bool, apiKey: String) async throws -> Comment {
        let path = "feedbacks/\(feedbackId)/comments"
        let body = CreateCommentRequest(content: content, userId: userId, isAdmin: isAdmin)

        logger.info("🟢 POST \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "POST", body: body, apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Comment.self, from: data)
            logger.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            logger.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func deleteComment(feedbackId: UUID, commentId: UUID, apiKey: String) async throws {
        let path = "feedbacks/\(feedbackId)/comments/\(commentId)"
        logger.info("🔴 DELETE \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "DELETE", apiKey: apiKey)
        try validateResponse(response, data: data, path: path)
        logger.info("✅ DELETE \(path) - completed")
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

        logger.info("🟢 POST \(path) (with API key)")
        let (data, response) = try await makeRequestWithApiKey(path: path, method: "POST", body: body, apiKey: apiKey)
        try validateResponse(response, data: data, path: path)

        do {
            let decoded = try decoder.decode(Feedback.self, from: data)
            logger.info("✅ POST \(path) - decoded successfully")
            return decoded
        } catch {
            logger.error("❌ POST \(path) - decoding failed: \(error.localizedDescription)")
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

        logger.info("📤 Request: \(method) \(url.absoluteString) (API key)")

        if let body = body {
            do {
                let bodyData = try encoder.encode(body)
                request.httpBody = bodyData
                if let bodyString = String(data: bodyData, encoding: .utf8) {
                    logger.debug("📦 Request body: \(bodyString)")
                }
            } catch {
                logger.error("❌ Failed to encode request body: \(error.localizedDescription)")
                throw error
            }
        }

        do {
            logger.info("🌐 Sending request to \(url.absoluteString)...")
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                logger.info("📥 Response: \(httpResponse.statusCode) for \(method) \(path)")

                if let responseString = String(data: data, encoding: .utf8) {
                    if data.count < 1000 {
                        logger.debug("📄 Response body: \(responseString)")
                    } else {
                        logger.debug("📄 Response body (truncated): \(responseString.prefix(500))...")
                    }
                }
            }

            return (data, response)
        } catch let error as URLError {
            logger.error("❌ URLError: \(error.code.rawValue) - \(error.localizedDescription)")
            throw APIError.networkError(error)
        } catch {
            logger.error("❌ Network error: \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data, path: String) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ \(path) - Invalid response (not HTTPURLResponse)")
            throw APIError.invalidResponse
        }

        let statusCode = httpResponse.statusCode
        logger.info("🔍 Validating response for \(path): status \(statusCode)")

        switch statusCode {
        case 200...299:
            logger.debug("✅ \(path) - Status \(statusCode) OK")
            return
        case 401:
            logger.error("❌ \(path) - 401 Unauthorized")
            throw APIError.unauthorized
        case 403:
            let message = parseErrorMessage(data)
            logger.error("❌ \(path) - 403 Forbidden: \(message)")
            throw APIError.forbidden(message)
        case 404:
            let message = parseErrorMessage(data)
            logger.error("❌ \(path) - 404 Not Found: \(message)")
            throw APIError.notFound(message)
        case 409:
            let message = parseErrorMessage(data)
            logger.error("❌ \(path) - 409 Conflict: \(message)")
            throw APIError.conflict(message)
        case 400:
            let message = parseErrorMessage(data)
            logger.error("❌ \(path) - 400 Bad Request: \(message)")
            throw APIError.badRequest(message)
        default:
            let message = parseErrorMessage(data)
            logger.error("❌ \(path) - \(statusCode) Server Error: \(message)")
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
        logger.info("🔵 GET \(path) (SDK users)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            logger.debug("📊 SDK Users - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.debug("📊 SDK Users - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode([SDKUser].self, from: data)
            logger.info("✅ GET \(path) - decoded \(decoded.count) SDK users")
            return decoded
        } catch let decodingError as DecodingError {
            logger.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getSDKUserStats(projectId: UUID) async throws -> SDKUserStats {
        let path = "users/project/\(projectId)/stats"
        logger.info("🔵 GET \(path) (SDK user stats)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            logger.debug("📊 SDK User Stats - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.debug("📊 SDK User Stats - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode(SDKUserStats.self, from: data)
            logger.info("✅ GET \(path) - decoded SDK user stats: totalUsers=\(decoded.totalUsers), totalMrr=\(decoded.totalMrr)")
            return decoded
        } catch let decodingError as DecodingError {
            logger.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - View Events API

    func getViewEventStats(projectId: UUID) async throws -> ViewEventsOverview {
        let path = "events/project/\(projectId)/stats"
        logger.info("🔵 GET \(path) (view event stats)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            logger.debug("📊 View Event Stats - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.debug("📊 View Event Stats - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode(ViewEventsOverview.self, from: data)
            logger.info("✅ GET \(path) - decoded view event stats: totalEvents=\(decoded.totalEvents), uniqueUsers=\(decoded.uniqueUsers)")
            return decoded
        } catch let decodingError as DecodingError {
            logger.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    func getViewEvents(projectId: UUID) async throws -> [ViewEvent] {
        let path = "events/project/\(projectId)"
        logger.info("🔵 GET \(path) (view events)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            logger.debug("📊 View Events - attempting to decode \(data.count) bytes")
            let decoded = try decoder.decode([ViewEvent].self, from: data)
            logger.info("✅ GET \(path) - decoded \(decoded.count) view events")
            return decoded
        } catch let decodingError as DecodingError {
            logger.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            throw APIError.decodingError(decodingError)
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Home Dashboard API

    func getHomeDashboard() async throws -> HomeDashboard {
        let path = "dashboard/home"
        logger.info("🔵 GET \(path) (home dashboard)")
        let (data, response) = try await makeRequest(path: path, method: "GET", requiresAuth: true)
        try validateResponse(response, data: data, path: path)

        do {
            logger.debug("📊 Home Dashboard - attempting to decode \(data.count) bytes")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.debug("📊 Home Dashboard - raw JSON: \(rawJSON)")
            }
            let decoded = try decoder.decode(HomeDashboard.self, from: data)
            logger.info("✅ GET \(path) - decoded home dashboard: totalProjects=\(decoded.totalProjects), totalFeedback=\(decoded.totalFeedback)")
            return decoded
        } catch let decodingError as DecodingError {
            logger.error("❌ GET \(path) - DecodingError: \(self.describeDecodingError(decodingError))")
            if let rawJSON = String(data: data, encoding: .utf8) {
                logger.error("❌ Raw JSON that failed to decode: \(rawJSON)")
            }
            throw APIError.decodingError(decodingError)
        } catch {
            logger.error("❌ GET \(path) - decoding failed: \(error.localizedDescription)")
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
}
