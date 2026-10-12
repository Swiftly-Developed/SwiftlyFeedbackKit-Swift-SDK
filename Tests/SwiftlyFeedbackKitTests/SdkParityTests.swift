//  SdkParityTests.swift
//  SwiftlyFeedbackKitTests
//
//  `QA-UNIT10-SDK-PARITY`, Swift SDK lane — `-04`, `-09`, `-15`…`-18`, `-21`, `-22`.
//
//  Every decode fixture is a committed copy of the server-generated corpus (the server's
//  `SdkWireCorpusTests` regenerates and byte-diffs `Fixtures/*.json`; §4.5's rule — a
//  parity fixture originates at the server's own encoder, never at a client assumption).
//  Error-map cases drive the REAL `APIClient` through `StubURLProtocol` (QA-UNIT01 `-08`'s
//  seam): `validateResponse` is `private` inside the actor, so the transport is the only
//  honest way in, and it exercises the real mapping rather than an extracted copy.
//
//  Cases marked ⚠️ RECORDED AS SHIPPED pin a measured divergence verbatim so that a future
//  product fix is a deliberate, visible red here rather than a silent behaviour change.
//
//  Run: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
//       swift test --filter SwiftlyFeedbackKitTests.SdkParity

import Foundation
import Testing
@testable import SwiftlyFeedbackKit

// MARK: - Shared fixture plumbing

private enum ParityFixtures {
    static var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    static func corpus(_ name: String) throws -> Data {
        try Data(contentsOf: fixturesDirectory.appendingPathComponent(name))
    }

    static let apiKey = "sf_test_stub_key_not_a_credential"
    static let userId = "user-under-test"

    static func makeClient(stub: StubURLProtocol.Session, apiKey: String = apiKey) throws -> APIClient {
        let baseURL = try #require(URL(string: "https://stub.invalid/api/v1"))
        return APIClient(baseURL: baseURL, apiKey: apiKey, userId: userId, session: stub.urlSession)
    }
}

// MARK: - -04 · list-decode tolerance

@Suite("SdkParityListTolerance")
struct SdkParityListToleranceTests {

    /// ⚠️ RECORDED AS SHIPPED. One unknown-status row poisons the ENTIRE `[Feedback]`
    /// decode: the SDK's `Feedback.status` is a strict enum, `APIClient.decode` is a bare
    /// `decoder.decode`, and no tolerant element-drop wrapper exists (`AGENTS.md` line 82;
    /// F1 — zero of six SDKs implement it; Flutter gained one on 2026-08-15 and is now the
    /// only SDK that drops the row). The integrator-visible consequence: the day the server
    /// adds a seventh status, every list screen in every shipped iOS app dead-ends.
    ///
    /// When the wrapper lands in `APIClient.decode<T>`, this case reddens — deliberately.
    @Test("The tolerance corpus poisons the whole list decode — recorded as shipped")
    func unknownStatusRowPoisonsTheWholeArray() async throws {
        let stub = StubURLProtocol.Session()
        let client = try ParityFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: try ParityFixtures.corpus("feedback-tolerance-corpus.json"))

        do {
            let _: [Feedback] = try await client.get(path: "feedbacks")
            Issue.record("""
                The whole-array decode SUCCEEDED. Either the tolerant element-drop wrapper \
                has landed (update this RECORDED case to assert the drop: three survivors, \
                in order, titles one/two/four) or the corpus lost its unknown-status row.
                """)
        } catch let error as SwiftlyFeedbackError {
            guard case .decodingError = error else {
                Issue.record("Expected .decodingError, got \(error)")
                return
            }
        }
    }

    /// The paired positive: the same corpus minus its unknown-status row decodes fully,
    /// in order — so the red above is attributable to that one row and nothing else.
    /// Constructed by runtime surgery on the corpus, never by a hand-written literal.
    @Test("The corpus minus the unknown row decodes: three survivors, in order")
    func corpusWithoutTheUnknownRowDecodes() async throws {
        let raw = try ParityFixtures.corpus("feedback-tolerance-corpus.json")
        var rows = try #require(try JSONSerialization.jsonObject(with: raw) as? [[String: Any]])
        #expect(rows.map { $0["status"] as? String } ==
                ["pending", "testflight", "quantum_launch", "completed"])
        rows.remove(at: 2)
        let surgery = try JSONSerialization.data(withJSONObject: rows)

        let stub = StubURLProtocol.Session()
        let client = try ParityFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: surgery)

        let decoded: [Feedback] = try await client.get(path: "feedbacks")
        #expect(decoded.map(\.title) ==
                ["Tolerance row one", "Tolerance row two", "Tolerance row four"])
        #expect(decoded.map(\.status) == [.pending, .testflight, .completed])
        // The unknown EXTRA KEY on row four is tolerated — only unknown enum VALUES kill
        // a row; Codable ignores unknown keys by default.
        #expect(decoded.last?.title == "Tolerance row four")
    }
}

// MARK: - -09 · the status → SwiftlyFeedbackError map, full set

@Suite("SdkParityErrorMap")
struct SdkParityErrorMapTests {

    private func thrownError(status: Int, body: String) async throws -> SwiftlyFeedbackError {
        let stub = StubURLProtocol.Session()
        let client = try ParityFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: Data(body.utf8), statusCode: status)
        do {
            let _: Feedback = try await client.get(path: "feedbacks/probe")
            Issue.record("Status \(status) did not throw")
            throw SwiftlyFeedbackError.invalidResponse
        } catch let error as SwiftlyFeedbackError {
            return error
        }
    }

    @Test("400 maps to .badRequest carrying the reason")
    func status400() async throws {
        let error = try await thrownError(status: 400, body: #"{"error":true,"reason":"Missing title"}"#)
        #expect(error == .badRequest(message: "Missing title"))
    }

    @Test("401 with 'invalid api key' prose maps to .invalidApiKey — a prose-coupled sniff")
    func status401InvalidKey() async throws {
        // The split is decided by SUBSTRING MATCH on the server's reason string
        // ("invalid api key", lowercased). Nothing links that literal to the server's
        // actual prose — the compile-green silent-inertness seam AGENTS.md describes.
        let error = try await thrownError(status: 401, body: #"{"error":true,"reason":"Invalid API Key"}"#)
        #expect(error == .invalidApiKey)
    }

    @Test("401 with any other prose maps to .unauthorized — and Vapor disagrees")
    func status401Other() async throws {
        // ⚠️ RECORDED DIVERGENCE: this body contains "api key" but not "invalid api key".
        // The Swift SDK yields .unauthorized; the Vapor SDK, in the same language, sniffs
        // the SHORTER substring "api key" and would yield .invalidApiKey for the very same
        // server message. Two SDKs, two different substrings, one wire contract.
        let error = try await thrownError(status: 401, body: #"{"error":true,"reason":"The API key is suspended"}"#)
        #expect(error == .unauthorized)
    }

    @Test("402 maps to .feedbackLimitReached — named for one of the three limits it represents")
    func status402() async throws {
        // ⚠️ RECORDED AS SHIPPED: project-count and member-count 402s surface under the
        // same case name. The naming is a client-side finding; the tier arithmetic is
        // QA-UNIT11's.
        let error = try await thrownError(status: 402, body: #"{"error":true,"reason":"Upgrade required"}"#)
        #expect(error == .feedbackLimitReached(message: "Upgrade required"))
    }

    @Test("403 maps to .serverError(403) — the Swift SDK has NO forbidden concept")
    func status403() async throws {
        // ⚠️ RECORDED AS SHIPPED. Every role-gate refusal — an archived-project write, a
        // vote on completed/rejected feedback — surfaces to an iOS integrator as "server
        // error". The Swift SDK is the only one of six without a 403 arm; the Vapor SDK,
        // in the same language, has `.forbidden`. When a forbidden case is added to
        // SwiftlyFeedbackError, this pin reddens — deliberately.
        let error = try await thrownError(status: 403, body: #"{"error":true,"reason":"Read-only project"}"#)
        #expect(error == .serverError(statusCode: 403))
    }

    @Test("404 maps to .notFound and 409 to .conflict")
    func status404And409() async throws {
        #expect(try await thrownError(status: 404, body: #"{"error":true,"reason":"Not Found"}"#) == .notFound)
        #expect(try await thrownError(status: 409, body: #"{"error":true,"reason":"Already voted"}"#) == .conflict)
    }

    @Test("422 maps to .serverError(422) — the validation envelope is unmapped in all six SDKs")
    func status422() async throws {
        // ⚠️ RECORDED AS SHIPPED. The server's validation envelope reaches every client as
        // a server/unknown error; no SDK maps 422.
        let error = try await thrownError(status: 422, body: #"{"error":true,"reason":"Validation failed"}"#)
        #expect(error == .serverError(statusCode: 422))
    }

    @Test("429 and 5xx map to .serverError carrying the actual status code")
    func status429And5xx() async throws {
        // The status code SURVIVES here — Kotlin's UnknownError is the one SDK that
        // discards it (statusCode == null), recorded in that lane.
        #expect(try await thrownError(status: 429, body: "{}") == .serverError(statusCode: 429))
        #expect(try await thrownError(status: 500, body: "{}") == .serverError(statusCode: 500))
        #expect(try await thrownError(status: 503, body: "{}") == .serverError(statusCode: 503))
    }

    @Test("Message extraction precedence is reason-then-message; a non-JSON body passes through raw")
    func messageExtractionPrecedence() async throws {
        // The four-way cross-SDK split, Swift's arm: `reason ?? message`. (JS reads only
        // body.reason; Flutter reason ?? error ?? message; Kotlin message ?? error ??
        // reason — inverted. The same 422 body yields different prose per platform.)
        let both = try await thrownError(status: 400, body: #"{"reason":"R-wins","message":"M-loses"}"#)
        #expect(both == .badRequest(message: "R-wins"))

        let messageOnly = try await thrownError(status: 400, body: #"{"message":"M-wins"}"#)
        #expect(messageOnly == .badRequest(message: "M-wins"))

        let nonJSON = try await thrownError(status: 400, body: "plain text failure")
        #expect(nonJSON == .badRequest(message: "plain text failure"))
    }
}

// MARK: - -15…-18 · configuration parity, Swift arm

@Suite("SdkParityConfig")
struct SdkParityConfigTests {

    private func sdkSource(_ relative: String) throws -> String {
        let url = WorkspaceSourceTree.packageRoot
            .appendingPathComponent("Sources/SwiftlyFeedbackKit")
            .appendingPathComponent(relative)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// ⚠️ RECORDED AS SHIPPED (`-15`, the break): the non-deprecated single-argument
    /// `configure(with:)` defaults to **localhost** while the other five SDKs default to
    /// production. A shipped app that calls it talks to nothing. Asserted on the source
    /// because calling `configure` mutates process-global SDK state from a detached Task.
    @Test("-15 · configure(with:) defaults to localhost — the one SDK of six that does")
    func configureWithDefaultsToLocalhost() throws {
        let source = try sdkSource("SwiftlyFeedback.swift")
        let configureBody = try #require(
            source.components(separatedBy: "public static func configure(with apiKey: String) {").last?
                .components(separatedBy: "}").first
        )
        #expect(configureBody.contains("http://localhost:8080/api/v1"))
        #expect(!configureBody.contains("api.prod.getfeedbackkit.com"))
    }

    /// `-18` — the environment enumeration, pinned per member with its host, plus the
    /// count. Swift declares four (local / development / testflight / production);
    /// `development`'s `api.dev` host exists in exactly two SDKs of six (Swift, Vapor);
    /// Kotlin declares a DIFFERENT four with no development environment at all; JS and
    /// Flutter declare none.
    @Test("-18 · FeedbackEnvironment is exactly four members with their pinned hosts")
    func environmentEnumeration() throws {
        #expect(FeedbackEnvironment.local.serverURL.absoluteString == "http://localhost:8080/api/v1")
        #expect(FeedbackEnvironment.development.serverURL.absoluteString == "https://api.dev.getfeedbackkit.com/api/v1")
        #expect(FeedbackEnvironment.testflight.serverURL.absoluteString == "https://api.testflight.getfeedbackkit.com/api/v1")
        #expect(FeedbackEnvironment.production.serverURL.absoluteString == "https://api.prod.getfeedbackkit.com/api/v1")

        // The 7th-member tripwire, from source: exactly four `case` declarations inside
        // the enum body (the enum is not CaseIterable, so arithmetic needs the text).
        let source = try sdkSource("Configuration/EnvironmentAPIKeys.swift")
        let enumBody = try #require(
            source.components(separatedBy: "public enum FeedbackEnvironment").dropFirst().first?
                .components(separatedBy: "\n}").first
        )
        // Member declarations only (`case local`), not the `case .local:` arms of the
        // enum's own switches over itself.
        let caseCount = enumBody.components(separatedBy: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces)
                .range(of: #"^case [a-z][A-Za-z]*$"#, options: .regularExpression) != nil
        }.count
        #expect(caseCount == 4)
    }

    /// `-16` — the Swift SDK's stored base URL INCLUDES the `/api/v1` segment (all four
    /// environment URLs above end in it). Kotlin and Vapor store the origin and append at
    /// use; the effective defaults coincide, so only the stored-value claim can see the
    /// split — an integrator moving an override between the two conventions gets
    /// `/api/v1/api/v1` or loses the path.
    @Test("-16 · the stored URL semantic includes /api/v1")
    func baseURLSemanticIncludesAPIPath() {
        for environment in [FeedbackEnvironment.local, .development, .testflight, .production] {
            #expect(environment.serverURL.absoluteString.hasSuffix("/api/v1"))
        }
    }

    /// ⚠️ RECORDED AS SHIPPED (`-17`): an empty API key is accepted silently and reaches
    /// the wire as an empty `X-API-Key` header. Required-ness is compile-time only; only
    /// JS validates at runtime, and it throws a bare `Error`.
    @Test("-17 · an empty API key is accepted and sent as an empty header")
    func emptyAPIKeyIsAcceptedSilently() async throws {
        let stub = StubURLProtocol.Session()
        let client = try ParityFixtures.makeClient(stub: stub, apiKey: "")

        stub.enqueueResponse(data: try ParityFixtures.corpus("vote-wire-corpus.json"))
        let _: [VoteResult] = try await client.get(path: "feedbacks/probe/votes")

        let recorded = try #require(stub.recordedRequests.first)
        #expect(recorded.header("X-API-Key") == "")
    }

    /// `-18`'s timeout row: the Swift SDK configures NO request timeout anywhere — the
    /// other four declare 30 000 ms. Asserted as a source negative with a paired positive
    /// (the files really are the client and configuration).
    @Test("-18 · the Swift SDK declares no timeout while four SDKs declare 30s")
    func noTimeoutDeclared() throws {
        let client = try sdkSource("Networking/APIClient.swift")
        let config = try sdkSource("Configuration/Config.swift")
        #expect(!client.contains("timeoutInterval"))
        #expect(!config.localizedCaseInsensitiveContains("timeout"))
        // Paired positives — the negatives above are about THESE files.
        #expect(client.contains("actor APIClient"))
        #expect(config.contains("SwiftlyFeedbackConfiguration"))
    }
}

// MARK: - -21 · required-field census, Swift arm (the immune positive)

@Suite("SdkParityCensus")
struct SdkParityCensusTests {

    /// Swift's `VoteResult` matches the server's `VoteResponseDTO` exactly — one of only
    /// two SDKs that do (with Vapor). Both boolean polarities land, through the real
    /// client, from the server-generated corpus. (Kotlin's `VoteResponse.success` throws
    /// on this same corpus; Flutter fabricates `success: true` — their lanes pin it.)
    @Test("-21 · the vote corpus decodes into VoteResult with every field bound")
    func voteCorpusDecodes() async throws {
        let stub = StubURLProtocol.Session()
        let client = try ParityFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: try ParityFixtures.corpus("vote-wire-corpus.json"))

        let votes: [VoteResult] = try await client.get(path: "feedbacks/probe/votes")
        #expect(votes.count == 2)
        #expect(votes[0].feedbackId.uuidString == "77777777-7777-4777-8777-777777777777")
        #expect(votes[0].voteCount == 8)
        #expect(votes[0].hasVoted == true)
        #expect(votes[1].hasVoted == false)
        #expect(votes[1].voteCount == 0)
    }

    /// Swift's `ViewEventResponse` also matches the server exactly, including the absent
    /// optional `properties` on the sparse row. (Flutter's `TrackedEvent` cannot decode
    /// this payload at all — `name` vs `event_name` — and Kotlin's `TrackEventResponse`
    /// throws on its required `success`; their lanes pin both.)
    @Test("-21 · the event corpus decodes into ViewEventResponse with every field bound")
    func eventCorpusDecodes() async throws {
        let stub = StubURLProtocol.Session()
        let client = try ParityFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: try ParityFixtures.corpus("event-wire-corpus.json"))

        let events: [ViewEventResponse] = try await client.get(path: "events")
        #expect(events.count == 2)
        #expect(events[0].eventName == "feedback_list")
        #expect(events[0].userId == "fixture-end-user")
        #expect(events[0].properties == ["source": "fixture-tab"])
        #expect(events[0].createdAt != nil)
        #expect(events[1].eventName == "submit_feedback")
        #expect(events[1].properties == nil)
    }
}

// MARK: - -22 · encode-direction key contract, Swift arm (the immune positive)

@Suite("SdkParityEncodeDirection")
struct SdkParityEncodeDirectionTests {

    /// The five private request DTOs in `SwiftlyFeedback.swift`, read from source (they
    /// are `private` and unconstructable from here — the seam test's comment routes their
    /// SHAPE to this suite). Each property name's snake_case image must be a key the
    /// server's request DTO decodes, with the canon loaded from the generated
    /// `request-wire-corpus.json` — never retyped.
    private static let requestStructs: [(swiftName: String, canonKey: String)] = [
        ("CreateFeedbackRequest", "create_feedback"),
        ("VoteRequest", "create_vote"),
        ("CreateCommentRequest", "create_comment"),
        ("RegisterUserRequest", "register_sdk_user"),
        ("TrackViewEventRequest", "track_view_event"),
    ]

    private func propertyNames(of structName: String, in source: String) throws -> [String] {
        let body = try #require(
            source.components(separatedBy: "private struct \(structName)").dropFirst().first?
                .components(separatedBy: "}").first,
            "private struct \(structName) not found in SwiftlyFeedback.swift"
        )
        return body.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("let ") else { return nil }
            return trimmed.dropFirst(4).components(separatedBy: ":").first?
                .trimmingCharacters(in: .whitespaces)
        }
    }

    /// Replicates `.convertToSnakeCase` for simple camelCase. Safe here because no request
    /// property carries a consecutive-capital run — asserted below, since the strategy and
    /// this replica DIVERGE exactly there (the totalMRR trap).
    private func snakeCased(_ name: String) -> String {
        var out = ""
        for character in name {
            if character.isUppercase {
                out.append("_")
                out.append(Character(character.lowercased()))
            } else {
                out.append(character)
            }
        }
        return out
    }

    @Test("-22 · every request DTO's emitted key set equals the server's request canon")
    func requestKeySetsMatchTheServerCanon() throws {
        let source = try String(
            contentsOf: WorkspaceSourceTree.packageRoot
                .appendingPathComponent("Sources/SwiftlyFeedbackKit/SwiftlyFeedback.swift"),
            encoding: .utf8
        )
        let canonData = try ParityFixtures.corpus("request-wire-corpus.json")
        let canon = try #require(
            try JSONSerialization.jsonObject(with: canonData) as? [String: [String: Any]]
        )

        for entry in Self.requestStructs {
            let properties = try propertyNames(of: entry.swiftName, in: source)
            #expect(!properties.isEmpty, "\(entry.swiftName) scan found no properties")

            // The acronym guard: the snake_case replica (and the strategy itself) is only
            // trustworthy on names without consecutive capitals.
            for property in properties {
                #expect(property.range(of: "[A-Z]{2}", options: .regularExpression) == nil,
                        "\(entry.swiftName).\(property) carries an acronym run — re-derive by strategy")
            }

            let emitted = Set(properties.map(snakeCased))
            let serverKeys = Set(try #require(canon[entry.canonKey]).keys)
            #expect(
                emitted == serverKeys,
                """
                \(entry.swiftName) emits \(emitted.sorted()) but the server's \
                \(entry.canonKey) decodes \(serverKeys.sorted()). Kotlin and Flutter \
                diverge here (camelCase mailing-list keys, email vs user_email) — the \
                Swift SDK derives keys from the strategy and must stay exactly aligned.
                """
            )
        }
        #expect(Self.requestStructs.count == 5)
    }
}
