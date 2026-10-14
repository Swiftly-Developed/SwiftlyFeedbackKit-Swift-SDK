import Foundation

/// Who a comment row should name.
///
/// Own comments are Me even when that person is also an admin. Everyone else's
/// admin comments stay Admin, and the rest stay User.
public enum CommentAuthorRole: Equatable, Sendable {
    case me
    case admin
    case user

    public static func resolve(commentUserId: String, isAdmin: Bool, currentUserId: String?) -> Self {
        if let currentUserId, !currentUserId.isEmpty, commentUserId == currentUserId {
            return .me
        }
        if isAdmin {
            return .admin
        }
        return .user
    }
}
