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
            return String(localized: "error.invalidResponse.message", bundle: #bundle)
        case .badRequest(let message):
            return message ?? String(localized: "error.badRequest.message", bundle: #bundle)
        case .unauthorized:
            return String(localized: "error.unauthorized.message", bundle: #bundle)
        case .invalidApiKey:
            return String(localized: "error.invalidApiKey.message", bundle: #bundle)
        case .notFound:
            return String(localized: "error.notFound.message", bundle: #bundle)
        case .conflict:
            return String(localized: "error.conflict.message", bundle: #bundle)
        case .serverError(let statusCode):
            return String(format: String(localized: "error.serverError.message", bundle: #bundle), statusCode)
        case .networkError(let error):
            return String(format: String(localized: "error.networkError.message", bundle: #bundle), error.localizedDescription)
        case .decodingError(let error):
            return String(format: String(localized: "error.decodingError.message", bundle: #bundle), error.localizedDescription)
        case .feedbackLimitReached(let message):
            return message ?? String(localized: "error.feedbackLimit.message", bundle: #bundle)
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
