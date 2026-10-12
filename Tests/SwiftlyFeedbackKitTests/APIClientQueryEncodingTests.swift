//  APIClientQueryEncodingTests.swift
//  SwiftlyFeedbackKitTests
//
//  Regression cover for "the Swift SDK's status filter is a live 404"
//  (docs/fixes/2026-08-25-swift-sdk-query-becomes-a-path-segment.md).
//
//  The defect: the facade concatenated the query INTO the path and `APIClient` built its URL
//  with `baseURL.appendingPathComponent(path)`. That treats the whole string as one path
//  component and percent-escapes the `?`, so `feedbacks?status=pending` went out as the path
//  segment `feedbacks%3Fstatus=pending` and the server answered 404. Present unchanged in
//  1.0.0, 1.1.0 and 1.1.1 — the filter has never worked.
//
//  🔴 Two measurement traps this file exists to avoid
//  --------------------------------------------------
//  1. `URL.path` and a split of `absoluteString` on "?" BOTH report the broken URL as correct
//     (`.path` returns the *unescaped* "/api/v1/feedbacks?status=pending"). Only `URL.query`
//     — nil when broken — discriminates. Every assertion below reads `.query`.
//  2. Most "hostile" values an author reaches for first do NOT discriminate. Measured by
//     sabotaging `makeURL` back to each broken form and re-running this file:
//
//       * concatenated-into-the-path (the shipped 1.1.1 defect) — 5 of 7 tests red, 21
//         issues: every query vanishes, so even the controls fail.
//       * `URLComponents` without the `+` → `%2B` hardening — only 2 issues, both from
//         `a+b` and `c++`. All 7 control values stay GREEN.
//
//     So a suite built on `my event` / `ünïcode · dot` / `checkout 🛒` / `say "hi"` / `a=b`
//     / `a?b` / `a;b` would ship green over the plus-encoding failure entirely. They are
//     kept below as falsifiability controls, NOT as cover.
//
//  Run: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
//       swift test --filter SwiftlyFeedbackKitTests.APIClientQueryEncoding

import Foundation
import Testing
@testable import SwiftlyFeedbackKit

@Suite("APIClientQueryEncoding")
struct APIClientQueryEncodingTests {

    private static let baseURL = URL(string: "https://api.dev.getfeedbackkit.com/api/v1")!
    private static let apiKey = "sf_test_stub_key_not_a_credential"
    private static let userId = "user-under-test"

    // MARK: - The defect itself, at the URL builder

    @Test("A query item becomes a real query, not a path segment")
    func queryIsNotSwallowedIntoThePath() throws {
        let url = try APIClient.makeURL(
            baseURL: Self.baseURL,
            path: "feedbacks",
            queryItems: [URLQueryItem(name: "status", value: "pending")]
        )

        // The discriminating assertion: broken builds yield nil here.
        #expect(url.query == "status=pending")
        #expect(url.path == "/api/v1/feedbacks")
        // The escaped `?` is the defect's fingerprint.
        #expect(!url.absoluteString.contains("%3F"))
        #expect(url.absoluteString == "https://api.dev.getfeedbackkit.com/api/v1/feedbacks?status=pending")
    }

    @Test("Both filters travel together")
    func statusAndCategoryTogether() throws {
        let url = try APIClient.makeURL(
            baseURL: Self.baseURL,
            path: "feedbacks",
            queryItems: [
                URLQueryItem(name: "status", value: "in_progress"),
                URLQueryItem(name: "category", value: "bug_report"),
            ]
        )
        #expect(url.query == "status=in_progress&category=bug_report")
        #expect(url.path == "/api/v1/feedbacks")
    }

    @Test("No query items leaves the URL exactly as the path-only form")
    func emptyQueryIsUnchanged() throws {
        // Guards every other verb in the client — none of them may acquire a stray "?".
        let url = try APIClient.makeURL(baseURL: Self.baseURL, path: "feedbacks/abc/votes", queryItems: [])
        #expect(url.query == nil)
        #expect(url.absoluteString == "https://api.dev.getfeedbackkit.com/api/v1/feedbacks/abc/votes")
    }

    // MARK: - Encoding of hostile values
    //
    // Only these four discriminate between the broken builder, plain `URLComponents`, and the
    // shipped `URLComponents` + `+`→`%2B` form. Expectations are the ENCODED query, because
    // that is what the server parses.

    @Test("Values that actually discriminate are encoded exactly", arguments: [
        // (value, expected percent-encoded query)
        ("a&b=c",      "event_name=a%26b%3Dc"),   // else: injects a second parameter
        ("a#b",        "event_name=a%23b"),       // else: truncates — tail becomes a fragment
        ("a+b",        "event_name=a%2Bb"),       // else: Vapor plus-decodes it to a space
        ("100%20done", "event_name=100%2520done"),// else: server double-decodes
        ("c++",        "event_name=c%2B%2B"),
    ])
    func discriminatingValuesEncodeExactly(value: String, expected: String) throws {
        let url = try APIClient.makeURL(
            baseURL: Self.baseURL,
            path: "metrics",
            queryItems: [URLQueryItem(name: "event_name", value: value)]
        )
        #expect(url.query == expected)
    }

    @Test("Falsifiability controls: green against the broken builder too", arguments: [
        "my event", "ünïcode · dot", "checkout 🛒", "say \"hi\"", "a=b", "a?b", "a;b",
    ])
    func controlValuesRoundTrip(value: String) throws {
        // These prove the corpus is not merely permissive. They are NOT evidence of cover:
        // each of them passes against the pre-fix builder as well.
        let url = try APIClient.makeURL(
            baseURL: Self.baseURL,
            path: "metrics",
            queryItems: [URLQueryItem(name: "event_name", value: value)]
        )
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        #expect(components?.queryItems?.first?.value == value, "\(value) did not survive the round trip")
    }

    // MARK: - Through the real client and the real transport

    @Test("The real APIClient sends the filter as a query on the wire")
    func realClientSendsAQuery() async throws {
        let session = StubURLProtocol.Session()
        let client = APIClient(
            baseURL: Self.baseURL,
            apiKey: Self.apiKey,
            userId: Self.userId,
            session: session.urlSession
        )
        session.enqueueResponse(data: Data("[]".utf8), statusCode: 200)

        let _: [Feedback] = try await client.get(
            path: "feedbacks",
            queryItems: [URLQueryItem(name: "status", value: "pending")]
        )

        let recorded = try #require(session.recordedRequests.first)
        let url = try #require(recorded.url)
        // `recorded.path` would read "/api/v1/feedbacks?status=pending" even when broken.
        #expect(url.query == "status=pending")
        #expect(url.path == "/api/v1/feedbacks")
        #expect(!url.absoluteString.contains("%3F"))
    }

    // MARK: - The facade no longer concatenates
    //
    // `SwiftlyFeedback` exposes no session seam, so its own contribution is gated at source.
    // This is the half of the defect that lived outside `APIClient`.

    @Test("getFeedback builds URLQueryItems instead of string-concatenating a query")
    func facadeDoesNotConcatenateAQuery() throws {
        try WorkspaceSourceTree.requireWorkspace()
        let source = try WorkspaceSourceTree.sdkSource("Sources/SwiftlyFeedbackKit/SwiftlyFeedback.swift")
        let body = try #require(
            WorkspaceSourceTree.slice(
                source,
                from: "public func getFeedback(status:",
                to: "/// Get a specific feedback item by ID."
            ),
            "getFeedback(status:category:) not found — this gate is no longer looking at anything"
        )

        // Falsifiability: the slice must actually contain the function it claims to.
        #expect(body.contains("client.get(path: \"feedbacks\""))
        #expect(body.contains("URLQueryItem(name: \"status\""))
        #expect(body.contains("URLQueryItem(name: \"category\""))
        // The defect's exact spelling: a "?" appended into the path string.
        #expect(!body.contains("path += \"?\""))
    }
}
