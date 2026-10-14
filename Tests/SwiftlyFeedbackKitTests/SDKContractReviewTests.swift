import Foundation
import os
import Testing
@testable import SwiftlyFeedbackKit

/// Wire and correctness pins added with the Swift SDK review.
///
/// The shared corpora stay the server's. `feedback-legacy-payload.json` is a client fixture
/// for a response shape those corpora do not carry: every status, including `testflight`,
/// with the fields added after 1.0.0 omitted, and a fractional-second timestamp.
@Suite("SDK contract review", .serialized)
struct SDKContractReviewTests {
    private static let apiKey = "sf_secret_key_do_not_log"
    private static let email = "pii-do-not-log@example.invalid"
    private static let userId = "pii-user-do-not-log"

    private static func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name)")
        return try Data(contentsOf: url)
    }

    @Test("A pre-roadmap payload decodes every status, including testflight and fractional dates")
    func legacyPayloadDecodes() throws {
        let items = try WireCoding.makeDecoder().decode(
            [Feedback].self,
            from: try Self.fixture("feedback-legacy-payload.json")
        )

        #expect(items.map(\.status) == [
            .pending, .approved, .inProgress, .testflight, .completed, .rejected
        ])
        #expect(items.allSatisfy { $0.isHiddenOverLimit == nil })
        #expect(items.allSatisfy { $0.rejectionReason == nil })
        let created = try #require(items[0].createdAt)
        #expect(abs(created.timeIntervalSince1970 - 1_700_000_000.123) < 0.001)
        #expect(items[3].status == .testflight)
        #expect(items[3].status.canVote)
        #expect(items[4].status.canVote == false)
    }

    @Test("A request times out after 30 seconds and a server error is not retried")
    func timeoutIsThirtySecondsAndServerErrorsAreNotRetried() async throws {
        let stub = StubURLProtocol.Session()
        let client = APIClient(
            baseURL: try #require(URL(string: "https://stub.invalid/api/v1")),
            apiKey: Self.apiKey,
            userId: Self.userId,
            session: stub.urlSession
        )
        stub.enqueueResponse(data: Data("{}".utf8), statusCode: 503)

        await #expect(throws: SwiftlyFeedbackError.serverError(statusCode: 503)) {
            let _: Feedback = try await client.get(path: "feedbacks/probe")
        }

        #expect(stub.recordedRequests.count == 1)
        #expect(stub.recordedRequests[0].timeoutInterval == APIClient.requestTimeout)
    }

    @Test("Logs omit the API key, email, and user id")
    func logsOmitCredentialsAndPersonalData() async throws {
        let bucket = OSAllocatedUnfairLock(initialState: [String]())
        let savedGate = SDKLogGate.isEnabled
        SDKLogGate.setEnabled(true)
        SDKLogger.setTestingSink { message in
            bucket.withLock { $0.append(message) }
        }
        defer {
            SDKLogger.setTestingSink(nil)
            SDKLogGate.setEnabled(savedGate)
        }

        let stub = StubURLProtocol.Session()
        let client = APIClient(
            baseURL: try #require(URL(string: "https://stub.invalid/api/v1")),
            apiKey: Self.apiKey,
            userId: Self.userId,
            session: stub.urlSession
        )
        struct Body: Encodable, Sendable {
            let userEmail: String
            let userId: String
        }
        stub.enqueueResponse(
            data: Data(
                #"{"error":true,"reason":"pii-do-not-log@example.invalid sf_secret_key_do_not_log"}"#.utf8
            ),
            statusCode: 400
        )

        await #expect(throws: SwiftlyFeedbackError.self) {
            let _: Feedback = try await client.post(
                path: "feedbacks",
                body: Body(userEmail: Self.email, userId: Self.userId)
            )
        }

        let lines = bucket.withLock { $0 }.joined(separator: "\n")
        #expect(lines.contains("POST feedbacks"))
        #expect(!lines.contains(Self.apiKey))
        #expect(!lines.contains(Self.email))
        #expect(!lines.contains(Self.userId))
        #expect(!lines.contains("user_email"))
    }
}

@Suite("User id lifecycle", .serialized)
@MainActor
struct UserIDLifecycleTests {
    private final class MemoryStore: UserIDStoring, @unchecked Sendable {
        private let lock = OSAllocatedUnfairLock<String?>(initialState: nil)
        func get() -> String? { lock.withLock { $0 } }
        func save(_ value: String) -> Bool {
            lock.withLock { $0 = value }
            return true
        }
        func delete() -> Bool {
            lock.withLock { $0 = nil }
            return true
        }
    }

    @Test("A custom id saved during the iCloud lookup is not overwritten")
    func customIDDuringICloudLookupWins() async {
        let store = OSAllocatedUnfairLock<String?>(initialState: nil)
        let resolved = await UserIdentifier.resolveUserId(
            customId: nil,
            readStored: { store.withLock { $0 } },
            writeStored: { value in store.withLock { $0 = value } },
            icloud: {
                store.withLock { $0 = "app-user-42" }
                return "icloud-record"
            },
            generate: { "local_generated" }
        )

        #expect(resolved == "app-user-42")
        #expect(store.withLock { $0 } == "app-user-42")
    }

    @Test("A blank custom id does not replace a stored id")
    func blankCustomIDIsIgnored() async {
        let resolved = await UserIdentifier.resolveUserId(
            customId: "   ",
            readStored: { "already-stored" },
            writeStored: { _ in Issue.record("blank custom id was stored") },
            icloud: { Issue.record("iCloud was consulted"); return nil },
            generate: { Issue.record("a local id was minted"); return "local_generated" }
        )
        #expect(resolved == "already-stored")
    }

    @Test("The iCloud lookup gives up when it does not answer in time")
    func iCloudLookupTimesOut() async {
        let started = ContinuousClock().now
        let resolved = await UserIdentifier.firstCompleted({
            try? await Task.sleep(for: .seconds(2))
            return "icloud-record"
        }, timeout: .milliseconds(40))
        #expect(resolved == nil)
        #expect(ContinuousClock().now - started < .milliseconds(500))
    }

    @Test("A fast iCloud answer is kept and does not wait out the timeout")
    func fastICloudAnswerWins() async {
        let started = ContinuousClock().now
        let resolved = await UserIdentifier.firstCompleted({
            "icloud-record"
        }, timeout: .seconds(2))
        #expect(resolved == "icloud-record")
        #expect(ContinuousClock().now - started < .milliseconds(500))
    }

    @Test("updateUser(customID:) is what the next request sends")
    func customIDIsSentOnTheNextRequest() async throws {
        let store = MemoryStore()
        let previous = UserIdentifier.swapStoreForTesting(store)
        let saved = SwiftlyFeedback.current
        defer {
            _ = UserIdentifier.swapStoreForTesting(previous)
            SwiftlyFeedback.current = saved
            _ = PendingUserID.take()
        }

        let stub = StubURLProtocol.Session()
        let baseURL = try #require(URL(string: "https://stub.invalid/api/v1"))
        let instance = SwiftlyFeedback(
            apiKey: "sf_test_stub_key_not_a_credential",
            userId: "anon-1",
            baseURL: baseURL,
            session: stub.urlSession
        )
        SwiftlyFeedback.current = instance
        stub.enqueueResponse(data: Data(#"{"user_id":"app-user-42"}"#.utf8))

        await SwiftlyFeedback.applyCustomUserID("app-user-42")

        let recorded = try #require(stub.recordedRequests.first)
        #expect(stub.recordedRequests.count == 1)
        #expect(recorded.header("X-User-Id") == "app-user-42")
        let body = try #require(recorded.body)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["user_id"] as? String == "app-user-42")
        #expect(store.get() == "app-user-42")
        #expect(!String(decoding: body, as: UTF8.self).contains("anon-1"))
    }

    @Test("A custom id set before configure is waiting when the client is published")
    func customIDSetBeforeConfigureIsPending() async throws {
        let store = MemoryStore()
        let previous = UserIdentifier.swapStoreForTesting(store)
        let saved = SwiftlyFeedback.current
        defer {
            _ = UserIdentifier.swapStoreForTesting(previous)
            SwiftlyFeedback.current = saved
            _ = PendingUserID.take()
        }

        SwiftlyFeedback.current = nil
        await SwiftlyFeedback.applyCustomUserID("  app-user-42  ")

        #expect(store.get() == "app-user-42")
        #expect(PendingUserID.take() == "app-user-42")
    }

    @Test("A blank custom id does not change the live client")
    func blankCustomIDDoesNotRegister() async throws {
        let store = MemoryStore()
        let previous = UserIdentifier.swapStoreForTesting(store)
        let saved = SwiftlyFeedback.current
        defer {
            _ = UserIdentifier.swapStoreForTesting(previous)
            SwiftlyFeedback.current = saved
        }

        let stub = StubURLProtocol.Session()
        let baseURL = try #require(URL(string: "https://stub.invalid/api/v1"))
        SwiftlyFeedback.current = SwiftlyFeedback(
            apiKey: "sf_test_stub_key_not_a_credential",
            userId: "anon-1",
            baseURL: baseURL,
            session: stub.urlSession
        )

        await SwiftlyFeedback.applyCustomUserID("   ")
        #expect(stub.recordedRequests.isEmpty)
        #expect(store.get() == nil)
    }
}
