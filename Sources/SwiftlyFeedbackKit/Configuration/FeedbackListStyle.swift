import Foundation

/// How `FeedbackListView` draws its rows.
///
/// Set through `SwiftlyFeedback.configuration.listStyle`. Both styles share the toolbar,
/// the Sort & Filter menu, search, and the "Filtered by" row; only the rows differ.
///
/// ```swift
/// // Keep the look from SwiftlyFeedbackKit 2.0
/// SwiftlyFeedback.configuration.listStyle = .classic
/// ```
public enum FeedbackListStyle: String, Sendable, CaseIterable {
    /// One grouped card per request: a status eyebrow, the full title and description,
    /// and a footer with category, comment count and a capsule vote button.
    /// See `docs/design/feedback01-showcase-2026-10/` in the repository.
    case showcase

    /// The plain list from SwiftlyFeedbackKit 2.0: a vote column on the leading edge
    /// and status and category badges under the title.
    case classic
}
