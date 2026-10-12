import Foundation

/// A search-scope token for the feedback list's `.searchable` field.
///
/// Tokens AND across families (status ∧ category) and OR within a family.
/// Status suggestions are derived from the loaded collection — never an
/// always-empty filter; category suggestions are all four cases.
enum FeedbackSearchToken: Identifiable, Hashable {
    case status(FeedbackStatus)
    case category(FeedbackCategory)

    var id: String {
        switch self {
        case .status(let status): return "status.\(status.rawValue)"
        case .category(let category): return "category.\(category.rawValue)"
        }
    }

    /// Localized, user-facing token text.
    var displayName: String {
        switch self {
        case .status(let status): return status.localizedDisplayName
        case .category(let category): return category.localizedDisplayName
        }
    }

    var iconName: String {
        switch self {
        case .status: return "line.3.horizontal.decrease.circle"
        case .category(let category): return category.iconName
        }
    }
}
