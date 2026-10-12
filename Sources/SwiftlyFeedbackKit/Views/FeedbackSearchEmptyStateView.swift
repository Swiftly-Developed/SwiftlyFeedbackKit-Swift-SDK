import SwiftUI

/// Filtered-empty state: the project has feedback, but none of it matches the
/// active search text/tokens. Distinct from project-empty
/// (`FeedbackEmptyStateView`) — the action clears the search, not submits.
///
/// Copy deliberately claims only "no match", never completeness — free-tier
/// items hidden over the limit may exist without appearing in any read.
/// A text query uses the system search empty state, which names the query.
/// Token-only filters keep the catalog copy, because there is no query string.
struct FeedbackSearchEmptyStateView: View {
    let query: String
    let onClearSearch: () -> Void

    var body: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            ContentUnavailableView {
                Label(String(localized: .searchEmptyTitle), systemImage: "magnifyingglass")
            } description: {
                Text(String(localized: .searchEmptyDescription))
            } actions: {
                Button(String(localized: .searchClearButton), action: onClearSearch)
            }
        } else {
            ContentUnavailableView.search(text: trimmed)
                .safeAreaInset(edge: .bottom) {
                    Button(String(localized: .searchClearButton), action: onClearSearch)
                        .buttonStyle(.bordered)
                }
        }
    }
}

#Preview {
    FeedbackSearchEmptyStateView(query: "dark mode") {}
}
