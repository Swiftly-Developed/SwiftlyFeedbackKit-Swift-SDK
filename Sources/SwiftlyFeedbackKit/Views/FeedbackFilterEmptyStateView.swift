import SwiftUI

/// Filtered-empty state: the project has feedback, but the status or category filters (with
/// or without search text) leave nothing. Distinct from project-empty and from search-empty.
///
/// Copy claims only "no match", never completeness: free-tier items hidden over the limit
/// may exist without appearing in any read.
struct FeedbackFilterEmptyStateView: View {
    let onClearFilters: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(String(localized: .filterEmptyTitle), systemImage: "line.3.horizontal.decrease.circle")
        } description: {
            Text(String(localized: .filterEmptyDescription))
        } actions: {
            Button(String(localized: .filterClearFilters), action: onClearFilters)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("fbk-filter-empty-clear")
        }
    }
}

#Preview {
    FeedbackFilterEmptyStateView {}
}
