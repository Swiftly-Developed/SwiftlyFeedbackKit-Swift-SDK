import Foundation

/// What changed on the board after a reader used report or block on a detail screen.
///
/// The list reloads when the event hides content. A report does not change the list.
public enum ModerationBoardEvent: Sendable {
    case reported
    case blockedAuthor
    case blockedCommenter
}
