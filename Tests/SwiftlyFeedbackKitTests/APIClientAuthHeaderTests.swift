//  APIClientAuthHeaderTests.swift
//  SwiftlyFeedbackKitTests
//
//  QA-UNIT03-AUTH test ID `-05` — the Swift SDK's auth rule is a CONSTANT, and that is
//  the claim.
//
//  `APIClient` has exactly one header-construction site and no branch: `X-API-Key` +
//  `X-User-Id`, on every request, and never an `Authorization` header. The Admin app needs a
//  `(path, method) → surface` rule because its API has two surfaces; the SDK needs none, and
//  proving the absence of a branch is what makes the day one appears a red test.
//
//  This is a SECURITY assertion, not a style one. The SDK ships inside third-party apps. The
//  project API key is "a scoping credential, not a secret" (API-DESIGN.md §7.1); a Bearer token
//  is the opposite, and a Bearer branch in this package is how an admin credential ends up in a
//  public binary.
//
//  Every case drives the REAL `APIClient` through the already-shipping `session:` parameter,
//  with QA-UNIT01-FOUNDATION `-08`'s `StubURLProtocol` installed. Nothing about the client is
//  replaced. `-05` extends UNIT01's single-GET header case to every verb entry point and adds
//  the "and nothing else" half, which a presence-only oracle cannot express.
//
//  Run: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
//       swift test --filter SwiftlyFeedbackKitTests.APIClientAuthHeaderTests

import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// Wraps a composed failure message so it can be passed to `#expect`.
///
/// Swift Testing's `Comment` is `ExpressibleByStringInterpolation`, so a *literal* converts —
/// but a **concatenated** message is a `String` expression and does not. The alternative is
/// reflowing every explanatory message onto one unbroken line, which is how they stop being read.
///
/// Fully qualified: the SDK exports its own `Comment` model type, so the bare name is ambiguous
/// in a target that imports both.
private func note(_ message: String) -> Testing.Comment { Testing.Comment(rawValue: message) }

@Suite("APIClientAuthHeader")
struct APIClientAuthHeaderTests {

    // MARK: - Fixtures

    private static let apiKey = "sf_test_stub_key_not_a_credential"
    private static let userId = "user-under-test"

    /// A fresh stub + a fresh client per `@Test`. No shared state, no reset hook.
    private static func makeClient(stub: StubURLProtocol.Session) throws -> APIClient {
        let baseURL = try #require(URL(string: "https://stub.invalid/api/v1"))
        return APIClient(baseURL: baseURL, apiKey: apiKey, userId: userId, session: stub.urlSession)
    }

    /// Mirrors `APIClient.init`'s encoder configuration verbatim.
    private static func makeSDKEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    /// `.iso8601` writes no fractional seconds, so only a whole-second instant survives its own
    /// round trip.
    private static let fixtureDate = Date(timeIntervalSince1970: 1_700_000_000)

    private static func makeFeedback(id: UUID) -> Feedback {
        Feedback(
            id: id,
            title: "Header probe",
            description: "A description written by the fixture.",
            status: .inProgress,
            category: .featureRequest,
            userId: userId,
            userEmail: "fixture@example.invalid",
            voteCount: 7,
            hasVoted: true,
            commentCount: 0,
            createdAt: fixtureDate,
            updatedAt: fixtureDate
        )
    }

    private static let probeID = UUID(uuidString: "0000000A-0000-4000-8000-00000000000B")!

    // MARK: - The oracle

    /// Every header name on `request` that could plausibly carry a credential.
    ///
    /// The set is asserted as an **equality**, not a membership: "X-API-Key is present" is true
    /// of a request that ALSO carries an `Authorization` header, and an oracle asserting a
    /// presence cannot see an extra. Matching on substrings rather than an exact allow-list is
    /// what makes a newly-added `Authorization`, `Cookie` or `X-Auth-Token` show up here rather
    /// than slip past a test that only knew to look for one name.
    private static func credentialHeaderNames(
        in request: StubURLProtocol.RecordedRequest
    ) -> Set<String> {
        let markers = ["authorization", "auth", "bearer", "token", "cookie", "credential", "key"]
        return Set(
            request.headers.keys
                .map { $0.lowercased() }
                .filter { name in markers.contains { name.contains($0) } }
        )
    }

    /// The positive half, asserted on every recorded request, plus the negative.
    private static func assertConstantAuthSurface(
        _ request: StubURLProtocol.RecordedRequest,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        // Positive: the key and the user id are present, with the configured values.
        #expect(
            request.header("X-API-Key") == apiKey,
            "X-API-Key missing or wrong on \(request.method) \(request.path ?? "?")",
            sourceLocation: sourceLocation
        )
        #expect(
            request.header("X-User-Id") == userId,
            "X-User-Id missing or wrong on \(request.method) \(request.path ?? "?")",
            sourceLocation: sourceLocation
        )

        // Negative: no Authorization header, by any spelling.
        #expect(
            request.header("Authorization") == nil,
            note("The SDK attached an Authorization header. A Bearer token in a package that "
            + "ships inside third-party apps is an admin credential in a public binary."),
            sourceLocation: sourceLocation
        )

        // And nothing else that could carry one.
        #expect(
            credentialHeaderNames(in: request) == ["x-api-key"],
            note("Credential-bearing headers on \(request.method) \(request.path ?? "?") were "
            + "\(credentialHeaderNames(in: request).sorted()), expected exactly [x-api-key]."),
            sourceLocation: sourceLocation
        )
    }

    // MARK: - `-05a` · Every verb entry point, driven through the real client

    @Test("-05a · GET carries the key and no Authorization")
    func getCarriesTheConstantSurface() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)
        stub.enqueueResponse(data: try Self.makeSDKEncoder().encode(Self.makeFeedback(id: Self.probeID)))

        // The request must actually have been BUILT — a green assembled only from absences is
        // also true of a request that never happened.
        let decoded: Feedback = try await client.get(path: "feedbacks/\(Self.probeID.uuidString)")
        #expect(decoded.id == Self.probeID)

        let recorded = try #require(stub.recordedRequests.first)
        #expect(recorded.method == "GET")
        Self.assertConstantAuthSurface(recorded)
    }

    @Test("-05b · POST carries the key and no Authorization")
    func postCarriesTheConstantSurface() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)
        stub.enqueueResponse(data: try Self.makeSDKEncoder().encode(Self.makeFeedback(id: Self.probeID)))

        let sent = Self.makeFeedback(id: Self.probeID)
        let decoded: Feedback = try await client.post(path: "feedbacks", body: sent)
        #expect(decoded.id == Self.probeID)

        let recorded = try #require(stub.recordedRequests.first)
        #expect(recorded.method == "POST")
        #expect(recorded.body != nil, "The POST body never reached the wire")
        Self.assertConstantAuthSurface(recorded)
    }

    @Test("-05d · DELETE (delete(path:body:), the only overload) carries the key and no Authorization")
    func deleteCarriesTheConstantSurface() async throws {
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)

        let vote = VoteResult(feedbackId: Self.probeID, voteCount: 6, hasVoted: false)
        stub.enqueueResponse(data: try Self.makeSDKEncoder().encode(vote))
        let result = try await client.delete(
            path: "feedbacks/\(Self.probeID.uuidString)/votes",
            body: ["user_id": Self.userId]
        )
        #expect(result.voteCount == 6)

        #expect(stub.recordedRequests.count == 1)
        let recorded = try #require(stub.recordedRequests.first)
        #expect(recorded.method == "DELETE")
        Self.assertConstantAuthSurface(recorded)
    }

    @Test("-05e · The surface does not change on a failure path")
    func errorResponsesDoNotChangeTheSurface() async throws {
        // A retry-with-different-credentials branch would most naturally appear here. Asserted
        // on the request the client sent for a 401, which is precisely the response an
        // `Authorization` fallback would react to.
        let stub = StubURLProtocol.Session()
        let client = try Self.makeClient(stub: stub)
        stub.enqueueResponse(data: Data(#"{"reason":"Invalid API key"}"#.utf8), statusCode: 401)

        await #expect(throws: SwiftlyFeedbackError.self) {
            let _: Feedback = try await client.get(path: "feedbacks/\(Self.probeID.uuidString)")
        }

        #expect(stub.recordedRequests.count == 1, "The client retried a 401 with a second request")
        Self.assertConstantAuthSurface(try #require(stub.recordedRequests.first))
    }

    // MARK: - `-05f` · The absence of a branch, in the source

    @Test("-05f · The SDK's sources construct no Authorization header anywhere")
    func sdkSourcesContainNoAuthorizationHeader() throws {
        // The behavioural cases above can only observe the paths a test happens to drive. This
        // one covers the whole package, including any method added tomorrow, and is the form in
        // which "a future SDK method adds a Bearer branch" goes red.
        let sourcesDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SwiftlyFeedbackKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // SwiftlyFeedbackKit (package root)
            .appendingPathComponent("Sources/SwiftlyFeedbackKit")

        #expect(
            FileManager.default.fileExists(atPath: sourcesDirectory.path),
            "SDK sources not found at \(sourcesDirectory.path)"
        )

        let files = (FileManager.default.enumerator(at: sourcesDirectory, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? [])
            .sorted { $0.path < $1.path }

        // Non-vacuity: an empty file list would make every check below trivially true.
        #expect(files.count >= 10, "Scanned only \(files.count) SDK source files")

        var authorizationSites: [String] = []
        var apiKeySites: [String] = []
        var userIdSites: [String] = []

        for file in files {
            guard let raw = try? String(contentsOf: file, encoding: .utf8) else { continue }
            for (number, line) in raw.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                // Comments stripped: this file's own header names the banned idiom, and so may
                // a doc comment in the SDK explaining why it is banned.
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasPrefix("*") else { continue }
                let code = line.range(of: "//").map { String(line[line.startIndex..<$0.lowerBound]) } ?? String(line)

                let site = "\(file.lastPathComponent):\(number + 1)"
                if code.lowercased().contains("authorization") { authorizationSites.append(site) }
                if code.contains(#"forHTTPHeaderField: "X-API-Key""#) { apiKeySites.append(site) }
                if code.contains(#"forHTTPHeaderField: "X-User-Id""#) { userIdSites.append(site) }
            }
        }

        #expect(
            authorizationSites.isEmpty,
            "The SDK now mentions Authorization at: \(authorizationSites.joined(separator: ", "))"
        )

        // Paired positives: exactly one construction site each, unconditional. Without these the
        // check above is a green built purely from an absence, and would pass on an SDK that
        // constructed no headers at all.
        #expect(
            apiKeySites.count == 1,
            note("Expected exactly one X-API-Key construction site, found \(apiKeySites.count): "
            + apiKeySites.joined(separator: ", "))
        )
        #expect(
            userIdSites.count == 1,
            note("Expected exactly one X-User-Id construction site, found \(userIdSites.count): "
            + userIdSites.joined(separator: ", "))
        )
    }
}
