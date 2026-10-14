import Foundation

/// The list's session-only status and category filters.
///
/// Both narrow the loaded collection client-side and combine with search text by AND.
/// Never persisted: a returning reader always sees the full list.
struct FeedbackListFilter: Equatable, Sendable {
    var status: FeedbackStatus?
    var category: FeedbackCategory?

    enum Component: Equatable, Sendable {
        case category(FeedbackCategory)
        case status(FeedbackStatus)

        var localizedName: String {
            switch self {
            case .category(let category): category.localizedPluralName
            case .status(let status): status.localizedDisplayName
            }
        }
    }

    init(status: FeedbackStatus? = nil, category: FeedbackCategory? = nil) {
        self.status = status
        self.category = category
    }

    var isActive: Bool { status != nil || category != nil }

    var activeCount: Int { (status == nil ? 0 : 1) + (category == nil ? 0 : 1) }

    /// Active filters in display order: category first, then status.
    var summaryComponents: [Component] {
        var components: [Component] = []
        if let category { components.append(.category(category)) }
        if let status { components.append(.status(status)) }
        return components
    }

    /// The bold names in the visible "Filtered by" row ("Bug Reports · In Progress").
    var summaryText: String {
        joined { String(localized: .filterSummaryJoin($0, $1)) }
    }

    /// The names as VoiceOver reads them ("Bug Reports, In Progress").
    var spokenSummaryText: String {
        joined { String(localized: .accessibilityFilterJoin($0, $1)) }
    }

    /// "Filtered by …" for the filter row's label and the menu's value.
    var spokenFilteredByText: String {
        String(localized: .accessibilityFilterFilteredBy(spokenSummaryText))
    }

    /// The Sort & Filter menu's accessibility value: the filter while filtered, the sort otherwise.
    func menuAccessibilityValue(sort: FeedbackSortOption) -> String {
        isActive ? spokenFilteredByText : sort.localizedName
    }

    func matches(_ feedback: Feedback) -> Bool {
        if let status, feedback.status != status { return false }
        if let category, feedback.category != category { return false }
        return true
    }

    mutating func clear() {
        status = nil
        category = nil
    }

    private func joined(_ pair: (String, String) -> String) -> String {
        let names = summaryComponents.map(\.localizedName)
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        default: return pair(names[0], names[1])
        }
    }
}
