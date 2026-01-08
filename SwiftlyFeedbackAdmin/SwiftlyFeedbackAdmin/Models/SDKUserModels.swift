import Foundation

// MARK: - SDK User Models
//
// All models are marked `nonisolated` to opt out of the project's default MainActor isolation.
// This allows their Codable conformances to be used from any actor context (e.g., AdminAPIClient).

/// Represents an SDK user (end user of the client app) with their MRR data
nonisolated
struct SDKUser: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: String
    let mrr: Double?
    let feedbackCount: Int
    let voteCount: Int
    let firstSeenAt: Date?
    let lastSeenAt: Date?

    /// Display-friendly user ID (truncated if too long)
    var displayUserId: String {
        if userId.count > 20 {
            return String(userId.prefix(8)) + "..." + String(userId.suffix(8))
        }
        return userId
    }

    /// User type based on the ID prefix
    var userType: UserType {
        if userId.hasPrefix("icloud_") {
            return .iCloud
        } else if userId.hasPrefix("local_") {
            return .local
        } else {
            return .custom
        }
    }

    enum UserType: String {
        case iCloud = "iCloud"
        case local = "Device"
        case custom = "Custom"

        var icon: String {
            switch self {
            case .iCloud: return "icloud"
            case .local: return "iphone"
            case .custom: return "person.badge.key"
            }
        }
    }
}

/// Statistics for SDK users in a project
/// Note: Property names use lowercase "mrr" to match Swift's convertFromSnakeCase
/// (total_mrr → totalMrr, not totalMRR)
nonisolated
struct SDKUserStats: Codable, Sendable {
    let totalUsers: Int
    let totalMrr: Double
    let usersWithMrr: Int
    let averageMrr: Double

    /// Formatted total MRR string
    var formattedTotalMRR: String {
        formatCurrency(totalMrr)
    }

    /// Formatted average MRR string
    var formattedAverageMRR: String {
        formatCurrency(averageMrr)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
