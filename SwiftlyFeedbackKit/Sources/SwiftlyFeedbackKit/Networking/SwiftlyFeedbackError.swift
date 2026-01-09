import Foundation

public enum SwiftlyFeedbackError: Error, LocalizedError, Equatable {
    case invalidResponse
    case badRequest(message: String?)
    case unauthorized
    case invalidApiKey
    case notFound
    case conflict
    case serverError(statusCode: Int)
    case networkError(underlying: Error)
    case decodingError(underlying: Error)
    case feedbackLimitReached(message: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .badRequest(let message):
            return message ?? "Bad request"
        case .unauthorized:
            return "Invalid API key or unauthorized access"
        case .invalidApiKey:
            return String(localized: "error.invalidApiKey.message", bundle: .module)
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
        case .feedbackLimitReached(let message):
            return message ?? String(localized: "error.feedbackLimit.message", bundle: .module)
        }
    }

    public static func == (lhs: SwiftlyFeedbackError, rhs: SwiftlyFeedbackError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.invalidApiKey, .invalidApiKey),
             (.notFound, .notFound),
             (.conflict, .conflict):
            return true
        case let (.badRequest(lhsMsg), .badRequest(rhsMsg)):
            return lhsMsg == rhsMsg
        case let (.serverError(lhsCode), .serverError(rhsCode)):
            return lhsCode == rhsCode
        case let (.networkError(lhsErr), .networkError(rhsErr)):
            return lhsErr.localizedDescription == rhsErr.localizedDescription
        case let (.decodingError(lhsErr), .decodingError(rhsErr)):
            return lhsErr.localizedDescription == rhsErr.localizedDescription
        case let (.feedbackLimitReached(lhsMsg), .feedbackLimitReached(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
