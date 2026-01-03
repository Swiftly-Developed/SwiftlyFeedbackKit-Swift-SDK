import Foundation

public enum SwiftlyFeedbackError: Error, LocalizedError {
    case invalidResponse
    case badRequest(message: String?)
    case unauthorized
    case notFound
    case conflict
    case serverError(statusCode: Int)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest(let message):
            return message ?? "Bad request"
        case .unauthorized:
            return "Invalid API key or unauthorized access"
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Conflict - resource already exists"
        case .serverError(let statusCode):
            return "Server error (status code: \(statusCode))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}
