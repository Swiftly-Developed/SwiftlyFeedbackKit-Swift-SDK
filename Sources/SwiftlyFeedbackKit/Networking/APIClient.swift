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

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
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
            request.httpBody = try encoder.encode(body)
        }

        return try await session.data(for: request)
    }

    func get<T: Decodable>(path: String) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "GET")
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    func patch<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "PATCH", body: body)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    func delete(path: String) async throws {
        let (_, response) = try await makeRequest(path: path, method: "DELETE")
        try validateResponse(response)
    }

    func delete<B: Encodable>(path: String, body: B) async throws -> VoteResult {
        let (data, response) = try await makeRequest(path: path, method: "DELETE", body: body)
        try validateResponse(response)
        return try decoder.decode(VoteResult.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SwiftlyFeedbackError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw SwiftlyFeedbackError.unauthorized
        case 404:
            throw SwiftlyFeedbackError.notFound
        case 409:
            throw SwiftlyFeedbackError.conflict
        default:
            throw SwiftlyFeedbackError.serverError(statusCode: httpResponse.statusCode)
        }
    }
}
