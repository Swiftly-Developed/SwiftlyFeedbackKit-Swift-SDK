import Foundation

/// Which body the loaded list shows. Exactly one at a time (`QA-UI09` `SdkListBranches`).
enum FeedbackListBranch: Equatable, Sendable {
    /// The project has no feedback at all.
    case projectEmpty
    /// Status or category filters (with or without search text) leave nothing.
    case filteredEmpty
    /// Search text alone leaves nothing.
    case searchEmpty
    case populated
}
