import Foundation

public actor APIClient {
    private let baseURL: URL
    private let apiKey: String
    private let userId: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL, apiKey: String, userId: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.userId = userId
        self.session = session

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase

        SDKLogger.debug("APIClient initialized with baseURL: \(baseURL.absoluteString)")
    }

    private func makeRequest(
        path: String,
        method: String,
        body: (any Encodable)? = nil
    ) async throws -> (Data, URLResponse) {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")

        if let body = body {
            let encodedBody = try encoder.encode(body)
            request.httpBody = encodedBody
            if let bodyString = String(data: encodedBody, encoding: .utf8) {
                SDKLogger.debug("Request body: \(bodyString)")
            }
        }

        SDKLogger.info("\(method) \(path)")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                SDKLogger.info("Response: \(httpResponse.statusCode)")

                if httpResponse.statusCode >= 400 {
                    if let responseBody = String(data: data, encoding: .utf8) {
                        SDKLogger.error("Error response: \(responseBody)")
                    }
                }
            }

            return (data, response)
        } catch {
            SDKLogger.error("Network error: \(error.localizedDescription)")
            throw error
        }
    }

    func get<T: Decodable>(path: String) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "GET")
        try validateResponse(response, data: data)
        return try decode(data)
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    func patch<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    func delete(path: String) async throws {
        let (data, response) = try await makeRequest(path: path, method: "DELETE")
        try validateResponse(response, data: data)
    }

    func delete<B: Encodable>(path: String, body: B) async throws -> VoteResult {
        let (data, response) = try await makeRequest(path: path, method: "DELETE", body: body)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if let responseString = String(data: data, encoding: .utf8) {
                SDKLogger.error("Decoding failed. Response: \(responseString)")
            }
            SDKLogger.error("Decoding error: \(error.localizedDescription)")
            throw SwiftlyFeedbackError.decodingError(underlying: error)
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            SDKLogger.error("Invalid response type")
            throw SwiftlyFeedbackError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            let errorMessage = parseErrorMessage(from: data)
            SDKLogger.error("Bad request (400): \(errorMessage ?? "Unknown error")")
            throw SwiftlyFeedbackError.badRequest(message: errorMessage)
        case 401:
            SDKLogger.error("Unauthorized (401)")
            throw SwiftlyFeedbackError.unauthorized
        case 404:
            SDKLogger.error("Not found (404)")
            throw SwiftlyFeedbackError.notFound
        case 409:
            SDKLogger.error("Conflict (409)")
            throw SwiftlyFeedbackError.conflict
        default:
            SDKLogger.error("Server error (\(httpResponse.statusCode))")
            throw SwiftlyFeedbackError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let error: Bool?
            let reason: String?
            let message: String?
        }

        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return errorResponse.reason ?? errorResponse.message
        }

        return String(data: data, encoding: .utf8)
    }
}
