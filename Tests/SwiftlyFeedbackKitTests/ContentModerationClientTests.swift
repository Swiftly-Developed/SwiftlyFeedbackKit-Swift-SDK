import Foundation
import Testing
@testable import SwiftlyFeedbackKit

@Suite("Content moderation client")
struct ContentModerationClientTests {
    @Test("reportFeedback posts the reason and the caller id")
    func reportFeedback() async throws {
        let posted = try await post { facade, feedbackID, _ in
            try await facade.reportFeedback(id: feedbackID, reason: .sexualContent)
        }
        #expect(posted.ok)
        #expect(posted.method == "POST")
        #expect(posted.path.hasSuffix("/feedbacks/\(posted.feedbackID)/reports"))
        #expect(posted.userHeader == ModerationFixtures.userId)
        #expect(posted.reason == "sexual_content")
        #expect(posted.userId == ModerationFixtures.userId)
    }

    @Test("reportComment posts under the comment's feedback")
    func reportComment() async throws {
        let posted = try await post { facade, feedbackID, commentID in
            try await facade.reportComment(id: commentID, on: feedbackID, reason: .harassment)
        }
        #expect(posted.ok)
        #expect(posted.method == "POST")
        #expect(posted.path.hasSuffix("/feedbacks/\(posted.feedbackID)/comments/\(posted.commentID)/reports"))
        #expect(posted.reason == "harassment")
        #expect(posted.userId == ModerationFixtures.userId)
    }

    @Test("blockUser posts the blocked id")
    func blockUser() async throws {
        let posted = try await post { facade, _, _ in
            try await facade.blockUser(id: "author-a")
        }
        #expect(posted.ok)
        #expect(posted.method == "POST")
        #expect(posted.path.hasSuffix("/blocks"))
        #expect(posted.blockedUserId == "author-a")
        #expect(posted.userId == ModerationFixtures.userId)
    }

    @Test("the objectionable-content token becomes the catalog sentence")
    func localizesObjectionableToken() {
        let rewritten = SwiftlyFeedback.localizeModeration(ModerationWireToken.objectionableContent)
        #expect(rewritten != ModerationWireToken.objectionableContent)
        #expect(rewritten?.isEmpty == false)

        #expect(SwiftlyFeedback.localizeModeration("Title cannot be empty") == "Title cannot be empty")
        #expect(SwiftlyFeedback.localizeModeration(nil) == nil)

        let described = SwiftlyFeedbackError
            .badRequest(message: ModerationWireToken.objectionableContent)
            .errorDescription
        #expect(described == rewritten)
    }

    @Test("the board contact default is the published address")
    @MainActor
    func contactDefault() {
        #expect(BoardModerationContact.defaultAddress == "moderation@getfeedbackkit.com")
        #expect(
            SwiftlyFeedbackConfiguration().moderationContactEmail
                == BoardModerationContact.defaultAddress
        )
    }

    @Test("the menu stays off the reader's own content")
    func menuVisibility() {
        #expect(ModerationMenuVisibility.isVisible(authorUserId: "a", currentUserId: "a") == false)
        #expect(ModerationMenuVisibility.isVisible(authorUserId: "a", currentUserId: "b"))
        #expect(ModerationMenuVisibility.isVisible(authorUserId: "a", currentUserId: nil))
        #expect(ModerationMenuVisibility.isVisible(authorUserId: "a", currentUserId: "  "))
    }

    @Test("report reasons match the server spellings")
    func reasonSpellings() {
        let raw = Set(ContentReportReason.allCases.map(\.rawValue))
        #expect(raw == ["spam", "harassment", "hate", "sexual_content", "violence", "other"])
    }

    private func post(
        send: (SwiftlyFeedback, UUID, UUID) async throws -> ModerationAcknowledgement
    ) async throws -> PostedModeration {
        let feedbackID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let commentID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let stub = StubURLProtocol.Session()
        stub.enqueueResponse(data: Data(#"{"ok":true}"#.utf8))
        let facade = try ModerationFixtures.makeFacade(stub: stub)
        let ack = try await send(facade, feedbackID, commentID)
        let request = try #require(stub.recordedRequests.first)
        let fields = try PostedModerationFields.read(request.body)
        return PostedModeration(
            ok: ack.ok,
            method: request.method,
            path: request.url?.path ?? "",
            userHeader: request.header("X-User-Id"),
            feedbackID: feedbackID.uuidString,
            commentID: commentID.uuidString,
            reason: fields.reason,
            userId: fields.userId,
            blockedUserId: fields.blockedUserId
        )
    }
}

/// The metrics fixture enum is file-private. This suite only needs a stubbed facade.
private enum ModerationFixtures {
    static let userId = "user-under-test"

    static func makeFacade(stub: StubURLProtocol.Session) throws -> SwiftlyFeedback {
        let baseURL = try #require(URL(string: "https://stub.invalid/api/v1"))
        return SwiftlyFeedback(
            apiKey: "sf_test_stub_key_not_a_credential",
            userId: userId,
            baseURL: baseURL,
            session: stub.urlSession
        )
    }
}

private struct PostedModeration: Sendable {
    var ok: Bool
    var method: String
    var path: String
    var userHeader: String?
    var feedbackID: String
    var commentID: String
    var reason: String?
    var userId: String?
    var blockedUserId: String?
}

private struct PostedModerationFields: Sendable {
    var reason: String?
    var userId: String?
    var blockedUserId: String?

    static func read(_ data: Data?) throws -> PostedModerationFields {
        let data = try #require(data)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return PostedModerationFields(
            reason: object["reason"] as? String,
            userId: object["user_id"] as? String,
            blockedUserId: object["blocked_user_id"] as? String
        )
    }
}
