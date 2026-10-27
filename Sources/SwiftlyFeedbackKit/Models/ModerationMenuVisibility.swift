import Foundation

/// Whether the report / block menu is offered for one author.
///
/// The current reader's own posts and comments do not show it. The server also
/// rejects a self-report and a self-block. An unknown current id still shows
/// the menu, because the server is the one that knows the caller.
enum ModerationMenuVisibility {
    static func isVisible(authorUserId: String, currentUserId: String?) -> Bool {
        guard let currentUserId else { return true }
        let trimmed = currentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return authorUserId != trimmed
    }
}
