import SwiftUI

/// Filtered-empty state: the project has feedback, but none of it matches the
/// active search text/tokens. Distinct from project-empty
/// (`FeedbackEmptyStateView`) — the action clears the search, not submits.
///
/// Copy deliberately claims only "no match", never completeness — free-tier
/// items hidden over the limit may exist without appearing in any read.
struct FeedbackSearchEmptyStateView: View {
    let onClearSearch: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(Strings.searchEmptyTitle, systemImage: "magnifyingglass")
        } description: {
            Text(Strings.searchEmptyDescription)
        } actions: {
            Button(Strings.searchClearButton) {
                onClearSearch()
            }
        }
    }
}

#Preview {
    FeedbackSearchEmptyStateView {}
}
