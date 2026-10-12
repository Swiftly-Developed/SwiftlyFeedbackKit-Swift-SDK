//  APIClientSeamTests.swift
//  SwiftlyFeedbackKitTests
//
//  QA-UNIT01-FOUNDATION test ID `-08` — the SDK seam.
//
//  Every case here drives the REAL `APIClient` through the already-shipping
//  `session:` parameter (`APIClient.swift:11`), with `StubURLProtocol` installed on an
//  ephemeral configuration. Nothing about the client is replaced: its header
//  construction, its `JSONEncoder`/`JSONDecoder` configuration and its
//  status→`SwiftlyFeedbackError` mapping are the code under test. No SDK source change.
//
//  Authored inside a named `@Suite` type per convention C3 — the package's file-scope
//  `@Test func`s are unfilterable and are not extended.
//
//  Run: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
//       swift test --filter SwiftlyFeedbackKitTests.APIClientSeamTests

import Foundation
import Testing
@testable import SwiftlyFeedbackKit

@Suite("APIClientSeam")
struct APIClientSeamTests {

    // MARK: - Fixtures
    //
    // Payloads are built by ENCODING THE SDK'S OWN MODEL TYPES with an encoder configured
    // exactly like `APIClient`'s. A hand-written JSON literal would be a second definition
    // of the wire contract and would drift from the first.

    private static let apiKey = "sf_test_stub_key_not_a_credential"
    private static let userId = "user-under-test"

    /// Mirrors `APIClient.init`'s encoder configuration verbatim.
    ///
    /// ⚠️ `.convertToSnakeCase` and `.convertFromSnakeCase` are NOT inverse for
    /// trailing-acronym properties (`projectID` → `project_id` → `projectId`). Every
    /// property on the models used here (`userId`, `feedbackId`, `mergedIntoId`, …) ends in
    /// a lowercase `d`, so the round trip is exact — this comment exists so the next author
    /// checks rather than assumes.
    private static func makeSDKEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    /// Mirrors `APIClient.init`'s decoder configuration verbatim.
    private static func makeSDKDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// A whole-second instant: `.iso8601` writes no fractional seconds, so only an integral
    /// `timeIntervalSince1970` survives the encode/decode round trip byte-for-byte.
    private static let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func makeFeedback(
        id: UUID,
        title: String,
        status: FeedbackStatus = .inProgress,
        voteCount: Int = 7
    ) -> Feedback {
        Feedback(
            id: id,
            title: title,
            description: "A description written by the fixture.",
            status: status,
            category: .featureRequest,
            userId: userId,
            userEmail: "fixture@example.invalid",
            voteCount: voteCount,
            hasVoted: true,
            commentCount: 3,
            createdAt: fixtureDate,
            updatedAt: fixtureDate
        )
    }

    /// A fresh stub + a fresh client, per `@Test`. No shared state, no reset hook.
    private static func makeClient(stub: StubURLProtocol.Session) throws -> APIClient {
        let baseURL = try #require(URL(string: "https://stub.invalid/api/v1"))
        return APIClient(
            baseURL: baseURL,
            apiKey: apiKey,
            userId: userId,
            session: stub.urlSession
        )
    }

    // MARK: - `-08` · A canned body surfaces as the SDK's decoded model

    @Test("A canned body decodes into the SDK's own model through the real client")
    func cannedBodySurfacesAsDecodedModel() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        let firstID = try #require(UUID(uuidString: "11111111-2222-3333-4444-555555555555"))
        let secondID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let fixtures = [
            Self.makeFeedback(id: firstID, title: "Dark mode", status: .inProgress, voteCount: 42),
            Self.makeFeedback(id: secondID, title: "Export to CSV", status: .completed, voteCount: 3)
        ]
        stub.enqueueResponse(data: try Self.makeSDKEncoder().encode(fixtures))

        let decoded: [Feedback] = try await client.get(path: "feedbacks")

        // Array-element ORDER is contractual; object-key order is not (C6).
        #expect(decoded.count == 2)
        #expect(decoded.map(\.id) == [firstID, secondID])
        #expect(decoded.map(\.title) == ["Dark mode", "Export to CSV"])
        // The snake-cased wire keys had to survive `.convertFromSnakeCase` for these to land.
        #expect(decoded.map(\.status) == [.inProgress, .completed])
        #expect(decoded.map(\.voteCount) == [42, 3])
        #expect(decoded.map(\.userId) == [Self.userId, Self.userId])
        #expect(decoded.first?.createdAt == Self.fixtureDate)

        // C8 — the case reached the code it claims to cover.
        #expect(stub.recordedRequests.count == 1)
    }

    // MARK: - `-08` · The real client attaches `X-API-Key`

    @Test("The real client attaches X-API-Key and X-User-Id to the request it sends")
    func realClientAttachesAuthHeaders() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        let id = try #require(UUID(uuidString: "0000000A-0000-4000-8000-00000000000B"))
        stub.enqueueResponse(
            data: try Self.makeSDKEncoder().encode(Self.makeFeedback(id: id, title: "Header probe"))
        )

        let decoded: Feedback = try await client.get(path: "feedbacks/\(id.uuidString)")
        #expect(decoded.id == id)

        let recorded = try #require(stub.recordedRequests.first)
        #expect(recorded.header("X-API-Key") == Self.apiKey)
        #expect(recorded.header("X-User-Id") == Self.userId)
        #expect(recorded.header("Content-Type") == "application/json")
        #expect(recorded.method == "GET")
        // URL construction sits below the seam, so the recorded path is the only oracle for it.
        #expect(recorded.path == "/api/v1/feedbacks/\(id.uuidString)")
        #expect(recorded.body == nil)
    }

    // MARK: - `-08` · The real encoder's bytes reach the wire and are recorded

    @Test("A POST body is encoded by the real client, reaches the wire, and is recorded")
    func postBodyIsEncodedByTheRealClientAndRecorded() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        // The production request DTOs (`CreateFeedbackRequest`, `VoteRequest`, …) are
        // `private` inside `SwiftlyFeedback.swift` and unreachable from the test target.
        // A product MODEL type stands in: the claim under test is the client's byte
        // handling — that its encoder ran with `.convertToSnakeCase` and that the bytes
        // arrived — not any particular request DTO's shape, which is `QA-UNIT10`'s.
        let sentID = try #require(UUID(uuidString: "C0000000-0000-4000-8000-000000000001"))
        let echoedID = try #require(UUID(uuidString: "C0000000-0000-4000-8000-000000000002"))
        let sent = Self.makeFeedback(id: sentID, title: "Submitted title")
        let echoed = Self.makeFeedback(id: echoedID, title: "Server-assigned title")

        stub.enqueueResponse(data: try Self.makeSDKEncoder().encode(echoed))

        let response: Feedback = try await client.post(path: "feedbacks", body: sent)
        #expect(response.id == echoedID)
        #expect(response.title == "Server-assigned title")

        let recorded = try #require(stub.recordedRequests.first)
        #expect(recorded.method == "POST")
        #expect(recorded.path == "/api/v1/feedbacks")

        // ⚠️ `URLProtocol` often sees the body as `httpBodyStream`, not `httpBody`. A stub
        // that reads only `httpBody` records `nil` here and this assertion passes vacuously.
        let body = try #require(recorded.body)
        #expect(!body.isEmpty)

        // Never byte-compare two JSON bodies (C6) — decode through the product's own type.
        let roundTripped = try Self.makeSDKDecoder().decode(Feedback.self, from: body)
        #expect(roundTripped.id == sentID)
        #expect(roundTripped.title == "Submitted title")
        #expect(roundTripped.createdAt == Self.fixtureDate)

        // The real encoder's key strategy is observable in the bytes themselves.
        let wireKeys = try #require(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        ).keys
        #expect(wireKeys.contains("user_id"))
        #expect(wireKeys.contains("vote_count"))
        #expect(!wireKeys.contains("userId"))
    }

    // MARK: - `-08` · A scripted non-2xx becomes the SDK's mapped error

    @Test("A scripted 404 maps to SwiftlyFeedbackError.notFound, paired with a 200 success")
    func nonSuccessStatusMapsToSDKError() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        let id = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))

        // C7 — the positive half. Without it, a 404 assertion is a negative oracle that
        // would also pass if the request never reached the client's status mapping at all.
        stub.enqueueResponse(
            data: try Self.makeSDKEncoder().encode(Self.makeFeedback(id: id, title: "Present"))
        )
        let found: Feedback = try await client.get(path: "feedbacks/\(id.uuidString)")
        #expect(found.title == "Present")

        // The negative half: same client, same path shape, only the status differs.
        stub.enqueueResponse(data: Data("{\"error\":true,\"reason\":\"Not Found\"}".utf8), statusCode: 404)
        await #expect(throws: SwiftlyFeedbackError.notFound) {
            let _: Feedback = try await client.get(path: "feedbacks/\(id.uuidString)")
        }

        #expect(stub.recordedRequests.count == 2)
    }

    @Test("A scripted 401 naming an invalid API key maps to SwiftlyFeedbackError.invalidApiKey")
    func invalidApiKeyStatusMapsToDistinctSDKError() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        // The reason string is what routes 401 to `.invalidApiKey` rather than
        // `.unauthorized`, so this also exercises the client's real `parseErrorMessage`.
        stub.enqueueResponse(
            data: Data("{\"error\":true,\"reason\":\"Invalid API key\"}".utf8),
            statusCode: 401
        )

        await #expect(throws: SwiftlyFeedbackError.invalidApiKey) {
            let _: [Feedback] = try await client.get(path: "feedbacks")
        }

        #expect(stub.recordedRequests.count == 1)
    }

    // MARK: - `-08` · A scripted transport error becomes the SDK's mapped error

    @Test("A scripted transport failure propagates out of the real client unwrapped")
    func transportErrorPropagatesFromRealClient() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        stub.enqueueFailure(URLError(.notConnectedToInternet))

        do {
            let _: [Feedback] = try await client.get(path: "feedbacks")
            Issue.record("Expected the scripted transport failure to throw")
        } catch let error as URLError {
            // `makeRequest`'s catch-all re-throws the underlying error verbatim — it does
            // NOT wrap it in `SwiftlyFeedbackError.networkError`. Asserting the SDK's
            // actual mapping, not the one the error enum's shape suggests.
            #expect(error.code == .notConnectedToInternet)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }

        #expect(stub.recordedRequests.count == 1)
    }

    @Test("A scripted URLError.cancelled is mapped by the real client to CancellationError")
    func cancellationTransportErrorIsMappedToCancellationError() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        stub.enqueueFailure(URLError(.cancelled))

        do {
            let _: [Feedback] = try await client.get(path: "feedbacks")
            Issue.record("Expected the scripted cancellation to throw")
        } catch {
            // This IS a real mapping in `APIClient.makeRequest` and the only transport-level
            // one it performs, so it is the transport case worth pinning.
            #expect(error is CancellationError)
            #expect(!(error is URLError))
        }

        #expect(stub.recordedRequests.count == 1)
    }
}
