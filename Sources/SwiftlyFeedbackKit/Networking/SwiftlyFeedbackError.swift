import Foundation

/// Every failure the SDK surfaces to a host app.
///
/// ⚠️ `Equatable` is **hand-written** below, ending in `default: return false`. A case added
/// without its own `==` arm compiles clean and then compares unequal **to itself**, which
/// makes `error == .rateLimited(message: nil)` fail with no hint as to why. Adding a case
/// means three edits, always: the declaration, an ``errorDescription`` arm, and an `==` arm.
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
    /// A 402 the metrics API raised because the requested read is Pro-only.
    ///
    /// Keyed on the enveloped `error.code`, never on the status: the feedback, project and
    /// member caps also answer 402, in the boolean body shape, and keep
    /// ``feedbackLimitReached(message:)``.
    case tierUpgradeRequired(code: MetricsErrorCode?, message: String?)
    /// A 403 refusing one measure on the `X-API-Key` surface.
    ///
    /// `measure` is the measure **as the server named it**, read out of the envelope — not
    /// re-derived from the request. The refusal is about the *surface*: the same measure is
    /// readable on the authenticated project endpoint.
    case measureNotAvailable(measure: String?, message: String?)
    /// A 403 from the shared middleware — a role, access or suspension refusal, carrying no
    /// machine-readable code. Deliberately distinct from
    /// ``measureNotAvailable(measure:message:)``.
    case forbidden(message: String?)
    /// A 429. The `X-API-Key` metrics family is rate-limited at 60 requests per 60 seconds.
    case rateLimited(message: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return String(localized: .errorInvalidResponseMessage)
        case .badRequest(let message):
            return message ?? String(localized: .errorBadRequestMessage)
        case .unauthorized:
            return String(localized: .errorUnauthorizedMessage)
        case .invalidApiKey:
            return String(localized: .errorInvalidApiKeyMessage)
        case .notFound:
            return String(localized: .errorNotFoundMessage)
        case .conflict:
            return String(localized: .errorConflictMessage)
        case .serverError(let statusCode):
            return String(localized: .errorServerErrorMessage(statusCode))
        case .networkError(let error):
            return String(localized: .errorNetworkErrorMessage(error.localizedDescription))
        case .decodingError(let error):
            return String(localized: .errorDecodingErrorMessage(error.localizedDescription))
        case .feedbackLimitReached(let message):
            return message ?? String(localized: .errorFeedbackLimitMessage)
        case .tierUpgradeRequired(_, let message):
            return message ?? String(localized: .errorTierUpgradeRequiredMessage)
        case .measureNotAvailable(_, let message):
            return message ?? String(localized: .errorMeasureNotAvailableMessage)
        case .forbidden(let message):
            return message ?? String(localized: .errorForbiddenMessage)
        case .rateLimited(let message):
            return message ?? String(localized: .errorRateLimitedMessage)
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
        case let (.tierUpgradeRequired(lhsCode, lhsMsg), .tierUpgradeRequired(rhsCode, rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        case let (.measureNotAvailable(lhsMeasure, lhsMsg), .measureNotAvailable(rhsMeasure, rhsMsg)):
            return lhsMeasure == rhsMeasure && lhsMsg == rhsMsg
        case let (.forbidden(lhsMsg), .forbidden(rhsMsg)):
            return lhsMsg == rhsMsg
        case let (.rateLimited(lhsMsg), .rateLimited(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}
