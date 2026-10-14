import Testing
@testable import SwiftlyFeedbackKit

@Suite
struct CommentAuthorRoleTests {

    @Test func ownCommentIsMeEvenWhenAdmin() {
        #expect(CommentAuthorRole.resolve(commentUserId: "me", isAdmin: true, currentUserId: "me") == .me)
    }

    @Test func ownCommentIsMe() {
        #expect(CommentAuthorRole.resolve(commentUserId: "me", isAdmin: false, currentUserId: "me") == .me)
    }

    @Test func anotherAdminIsAdmin() {
        #expect(CommentAuthorRole.resolve(commentUserId: "other", isAdmin: true, currentUserId: "me") == .admin)
    }

    @Test func anotherPersonIsUser() {
        #expect(CommentAuthorRole.resolve(commentUserId: "other", isAdmin: false, currentUserId: "me") == .user)
    }

    @Test func aMissingCurrentUserDoesNotMatchAnyone() {
        #expect(CommentAuthorRole.resolve(commentUserId: "other", isAdmin: false, currentUserId: nil) == .user)
        #expect(CommentAuthorRole.resolve(commentUserId: "", isAdmin: false, currentUserId: nil) == .user)
        #expect(CommentAuthorRole.resolve(commentUserId: "other", isAdmin: true, currentUserId: "") == .admin)
    }
}
