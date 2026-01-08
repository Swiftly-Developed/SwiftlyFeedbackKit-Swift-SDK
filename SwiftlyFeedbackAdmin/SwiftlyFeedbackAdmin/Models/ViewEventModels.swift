import Foundation

// MARK: - View Event Models
//
// All models are marked `nonisolated` to opt out of the project's default MainActor isolation.
// This allows their Codable conformances to be used from any actor context (e.g., AdminAPIClient).

/// Represents a view event tracked from the SDK
nonisolated
struct ViewEvent: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let eventName: String
    let userId: String
    let properties: [String: String]?
    let createdAt: Date?

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

/// Statistics for a specific event type
nonisolated
struct ViewEventStats: Codable, Sendable {
    let eventName: String
    let totalCount: Int
    let uniqueUsers: Int
}

/// Overview of all view events for a project
nonisolated
struct ViewEventsOverview: Codable, Sendable {
    let totalEvents: Int
    let uniqueUsers: Int
    let eventBreakdown: [ViewEventStats]
    let recentEvents: [ViewEvent]
    let dailyStats: [DailyEventStats]
}

/// Daily statistics for events
nonisolated
struct DailyEventStats: Codable, Sendable, Identifiable {
    let date: String  // ISO date string (YYYY-MM-DD)
    let totalCount: Int
    let uniqueUsers: Int
    let eventBreakdown: [String: Int]

    var id: String { date }

    /// Parse the date string to a Date object
    var parsedDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.date(from: date)
    }

    /// Formatted date for display
    var displayDate: String {
        guard let parsed = parsedDate else { return date }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: parsed)
    }
}
