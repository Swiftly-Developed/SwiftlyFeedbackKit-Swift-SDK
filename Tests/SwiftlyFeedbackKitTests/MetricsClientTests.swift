//  MetricsClientTests.swift
//  SwiftlyFeedbackKitTests
//
//  METRICS03 phase 05's gate battery, `QA-UNIT10-SDK-PARITY`'s Swift lane.
//
//  Every decode input is a committed copy of the SERVER-GENERATED corpus
//  (`Fixtures/metrics-wire-corpus.json`, `Fixtures/metrics-error-wire-corpus.json`). No
//  hand-written JSON response literal appears in this file: a client-authored fixture can
//  only ever prove the client agrees with itself.
//
//  Requests are observed through `StubURLProtocol.recordedRequests`, which sees the URL the
//  SDK actually put on the wire. ⚠️ Read `absoluteString`, never `.path`: `URL.path`
//  percent-DECODES, so a `?` escaped into the path prints as a bare `?` and the defect this
//  phase fixes is invisible there.
//
//  Run: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

import Foundation
import Testing
@testable import SwiftlyFeedbackKit

// MARK: - Shared plumbing

private enum MetricsFixtures {
    static var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
    }

    static func corpusData(_ name: String) throws -> Data {
        try Data(contentsOf: fixturesDirectory.appendingPathComponent(name))
    }

    /// One named row of the metrics wire corpus, re-serialised so the real client decodes it.
    static func metricsRow(_ key: String) throws -> Data {
        let root = try #require(
            try JSONSerialization.jsonObject(with: corpusData("metrics-wire-corpus.json"))
                as? [String: Any]
        )
        let row = try #require(root[key], "metrics-wire-corpus.json has no \"\(key)\" row")
        return try JSONSerialization.data(withJSONObject: row)
    }

    static func errorCorpus() throws -> [String: Any] {
        try #require(
            try JSONSerialization.jsonObject(with: corpusData("metrics-error-wire-corpus.json"))
                as? [String: Any]
        )
    }

    static let apiKey = "sf_test_stub_key_not_a_credential"
    static let userId = "user-under-test"
    static let baseURLString = "https://stub.invalid/api/v1"

    static func makeClient(stub: StubURLProtocol.Session) throws -> APIClient {
        let baseURL = try #require(URL(string: baseURLString))
        return APIClient(baseURL: baseURL, apiKey: apiKey, userId: userId, session: stub.urlSession)
    }

    /// The REAL facade, wired to the stub. `configure(with:)` mutates process-global state
    /// from a detached Task and is unusable in a parallel test target; the internal
    /// initializer is the seam.
    static func makeFacade(stub: StubURLProtocol.Session) throws -> SwiftlyFeedback {
        let baseURL = try #require(URL(string: baseURLString))
        return SwiftlyFeedback(
            apiKey: apiKey,
            userId: userId,
            baseURL: baseURL,
            session: stub.urlSession
        )
    }
}

/// Decodes a query string the way the server's `URLEncodedFormParser` does.
///
/// Its very first statement rewrites `+` to `%20` before anything is percent-decoded
/// (`URLEncodedFormParser.swift:6`), which is why a literal `+` left unescaped by
/// `URLQueryItem` arrives as a space. Modelling that here is what makes the round trip an
/// oracle rather than a restatement of Foundation's own behaviour.
private enum VaporFormSemantics {
    static func parse(_ query: String) -> [(name: String, value: String)] {
        let plusDecoded = query.replacingOccurrences(of: "+", with: "%20")
        return plusDecoded.split(separator: "&", omittingEmptySubsequences: false).map { pair in
            let halves = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(halves[0]).removingPercentEncoding ?? String(halves[0])
            let value = halves.count > 1
                ? (String(halves[1]).removingPercentEncoding ?? String(halves[1]))
                : ""
            return (name, value)
        }
    }
}

/// Strips Swift comments so an absence gate cannot be satisfied — or defeated — by prose.
///
/// Deliberately naive about `//` inside string literals: over-stripping can only make an
/// absence claim weaker, never falsely strong. Every caller pairs it with a non-vacuity
/// check, because a stripper that returned "" would turn every absence leg green.
private enum CommentStripper {
    static func strip(_ source: String) -> String {
        var out = ""
        var index = source.startIndex
        var inBlock = false
        while index < source.endIndex {
            let rest = source[index...]
            if inBlock {
                if rest.hasPrefix("*/") {
                    inBlock = false
                    index = source.index(index, offsetBy: 2)
                } else {
                    index = source.index(after: index)
                }
                continue
            }
            if rest.hasPrefix("/*") {
                inBlock = true
                index = source.index(index, offsetBy: 2)
                continue
            }
            if rest.hasPrefix("//") {
                while index < source.endIndex, source[index] != "\n" {
                    index = source.index(after: index)
                }
                continue
            }
            out.append(source[index])
            index = source.index(after: index)
        }
        return out
    }
}

/// The twelve hostile values, and the parity class each one exercises.
///
/// Seven are CONTROLS that the shipped joined-string builder already handled correctly.
/// They are here so the gate can tell "encoding improved" from "encoding changed" — a test
/// whose only hostile value is a space, an accent or an emoji is green against the broken
/// builder and proves nothing.
private enum HostileValues {
    static let breaking: [String] = [
        "a&b=c",                      // reserved delimiter — injects a parameter
        "a#b",                        // fragment delimiter — truncates the request
        "a+b",                        // Vapor plus-decodes `+` to a space
        "100%20done",                 // literal `%` — double-decodes
        "my event & more · ünïcode",  // the spec's own case; fails via the `&`
    ]
    static let controls: [String] = [
        "my event",
        "ünïcode · dot",
        "checkout 🛒",
        "say \"hi\"",
        "a=b",
        "a?b",
        "a;b",
    ]
    static let all: [String] = breaking + controls
}

/// One row of an encoder round trip. A named `Equatable` struct, because an array of tuples
/// is not `Equatable` and cannot be compared in one assertion.
private struct RoundTrip: Equatable, CustomStringConvertible {
    let input: String
    let decoded: String?
    let pairCount: Int

    var description: String {
        "\(input.debugDescription) -> \(decoded.map(\.debugDescription) ?? "nil") in \(pairCount) pair(s)"
    }
}

/// One recorded request URL. Same reason.
private struct RecordedURL: Equatable, CustomStringConvertible {
    let path: String
    let absoluteString: String
    var description: String { "\(path) -> \(absoluteString)" }
}

// MARK: - G1 · the encoder, over the five breaking classes and seven controls

@Suite("MetricsQueryEncoding")
struct MetricsQueryEncodingTests {

    private func roundTrip(_ value: String, through query: String?) -> RoundTrip {
        guard let query else { return RoundTrip(input: value, decoded: nil, pairCount: 0) }
        let pairs = VaporFormSemantics.parse(query)
        return RoundTrip(
            input: value,
            decoded: pairs.first(where: { $0.name == "event_name" })?.value,
            pairCount: pairs.count
        )
    }

    @Test("G1a · every hostile value survives URLQueryEncoding intact, 12 of 12")
    func encoderRoundTripsAllTwelve() {
        #expect(HostileValues.all.count == 12, "the corpus is fixed at 12 values across three SDKs")
        #expect(Set(HostileValues.all).count == 12, "the twelve must be distinct")

        let observed = HostileValues.all.map { value -> RoundTrip in
            let query = URLQueryEncoding.query([
                URLQueryItem(name: "event_name", value: value),
                URLQueryItem(name: "page", value: "1"),
            ])
            return roundTrip(value, through: query)
        }
        // Derived, not seeded: the expectation is "the input came back, in exactly the two
        // pairs that were sent". An injected third parameter shows up as a COUNT, which a
        // value-only oracle cannot see.
        let expected = HostileValues.all.map { RoundTrip(input: $0, decoded: $0, pairCount: 2) }

        // One assertion over the whole vector — a per-iteration assert reports several real
        // failures at a single source line and under-reports the rest.
        #expect(observed == expected)
    }

    @Test("G1b · the same twelve survive end to end through the real facade")
    func facadeRoundTripsAllTwelve() async throws {
        let stub = StubURLProtocol.Session()
        let facade = try MetricsFixtures.makeFacade(stub: stub)
        let page = try MetricsFixtures.metricsRow("events_page")

        for value in HostileValues.all {
            stub.enqueueResponse(data: page)
            _ = try await facade.metricsEvents(eventName: value, page: 1)
        }

        let recorded = stub.recordedRequests
        #expect(recorded.count == 12)

        let observed = recorded.enumerated().map { index, request -> RoundTrip in
            roundTrip(HostileValues.all[index], through: request.url?.query)
        }
        let expected = HostileValues.all.map { RoundTrip(input: $0, decoded: $0, pairCount: 2) }
        #expect(observed == expected)

        // The fragment class is only visible on the whole URL: a `#` that reached the wire
        // unescaped would truncate the request and the tail would never leave the client.
        #expect(recorded.allSatisfy { ($0.url?.fragment) == nil })
    }

    @Test("G1c · an empty item list produces no query at all, so query-less calls are unchanged")
    func emptyItemsProduceNoQuery() {
        #expect(URLQueryEncoding.query([]) == nil)
        #expect(URLQueryEncoding.query([URLQueryItem(name: "a", value: "b")]) == "a=b")
    }
}

// MARK: - G2 · every existing request is byte-identical, and the filtered one is fixed

@Suite("MetricsTransportURL")
struct MetricsTransportURLTests {

    /// The six shipped query-less shapes, pinned as literals. A derived expectation here
    /// would just restate the construction under test; these strings are what the shipped
    /// build produced before the change.
    private static let queryLessPaths: [RecordedURL] = [
        RecordedURL(path: "feedbacks",
                    absoluteString: "https://stub.invalid/api/v1/feedbacks"),
        RecordedURL(path: "feedbacks/77777777-7777-4777-8777-777777777777",
                    absoluteString: "https://stub.invalid/api/v1/feedbacks/77777777-7777-4777-8777-777777777777"),
        RecordedURL(path: "feedbacks/77777777-7777-4777-8777-777777777777/votes",
                    absoluteString: "https://stub.invalid/api/v1/feedbacks/77777777-7777-4777-8777-777777777777/votes"),
        RecordedURL(path: "feedbacks/77777777-7777-4777-8777-777777777777/comments",
                    absoluteString: "https://stub.invalid/api/v1/feedbacks/77777777-7777-4777-8777-777777777777/comments"),
        RecordedURL(path: "users/register",
                    absoluteString: "https://stub.invalid/api/v1/users/register"),
        RecordedURL(path: "events/track",
                    absoluteString: "https://stub.invalid/api/v1/events/track"),
    ]

    @Test("G2a · a query-less request is byte-identical to the shipped construction")
    func queryLessRequestsAreUnchanged() async throws {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)

        for entry in Self.queryLessPaths {
            stub.enqueueResponse(data: Data("[]".utf8))
            // Through the NEW verb with an empty item list — the case that must not move.
            let _: [Feedback] = try await client.get(path: entry.path, queryItems: [])
        }

        let observed = stub.recordedRequests.enumerated().map { index, request in
            RecordedURL(
                path: Self.queryLessPaths[index].path,
                absoluteString: request.url?.absoluteString ?? "<no url>"
            )
        }
        #expect(observed == Self.queryLessPaths)
        #expect(stub.recordedRequests.allSatisfy { $0.url?.query == nil })
        #expect(observed.count == 6)
    }

    @Test("G2b · the shipped get(path:) and the new overload agree byte for byte")
    func bothVerbsProduceTheSameURL() async throws {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)

        stub.enqueueResponse(data: Data("[]".utf8))
        let _: [Feedback] = try await client.get(path: "feedbacks")
        stub.enqueueResponse(data: Data("[]".utf8))
        let _: [Feedback] = try await client.get(path: "feedbacks", queryItems: [])

        let urls = stub.recordedRequests.map { $0.url?.absoluteString }
        #expect(urls.count == 2)
        #expect(urls[0] == urls[1])
    }

    @Test("G2c · getFeedback(status:) sends a real query — the shipped build sent %3F and 404'd")
    func statusFilterIsAQueryNotAPathSegment() async throws {
        let stub = StubURLProtocol.Session()
        let facade = try MetricsFixtures.makeFacade(stub: stub)

        stub.enqueueResponse(data: Data("[]".utf8))
        _ = try await facade.getFeedback(status: .pending)

        let request = try #require(stub.recordedRequests.first)
        let absolute = try #require(request.url?.absoluteString)

        // 🔴 The baseline this replaces: `.query` was nil and the URL carried `%3F`, because
        // the joined string went through `appendingPathComponent`. Reading `.path` here
        // would percent-DECODE and hide it.
        #expect(request.url?.query == "status=pending")
        #expect(!absolute.contains("%3F"))
        #expect(absolute == "https://stub.invalid/api/v1/feedbacks?status=pending")
    }

    @Test("G2d · both filters travel as two query parameters, in declaration order")
    func bothFiltersTravel() async throws {
        let stub = StubURLProtocol.Session()
        let facade = try MetricsFixtures.makeFacade(stub: stub)

        stub.enqueueResponse(data: Data("[]".utf8))
        _ = try await facade.getFeedback(status: .inProgress, category: .featureRequest)

        let query = try #require(stub.recordedRequests.first?.url?.query)
        let pairs = VaporFormSemantics.parse(query)
        #expect(pairs.map(\.name) == ["status", "category"])
        #expect(pairs.map(\.value) == ["in_progress", "feature_request"])
    }
}

// MARK: - G3 · the four operations send exactly the contract's wire keys

/// One operation's observed query, as a comparable value.
private struct ObservedQuery: Equatable, CustomStringConvertible {
    let operation: String
    let path: String
    let keys: Set<String>
    let measuresOccurrences: Int
    let statusOccurrences: Int
    let categoryOccurrences: Int
    let eventNameOccurrences: Int

    var description: String {
        "\(operation) \(path) keys=\(keys.sorted()) measures×\(measuresOccurrences)"
    }
}

@Suite("MetricsWireKeys")
struct MetricsWireKeyTests {

    private static let windowStart = Date(timeIntervalSince1970: 1_697_000_000)
    private static let windowEnd = Date(timeIntervalSince1970: 1_700_000_000)

    private func observe(
        operation: String,
        stub: StubURLProtocol.Session,
        at index: Int
    ) throws -> ObservedQuery {
        let request = stub.recordedRequests[index]
        let query = try #require(request.url?.query, "\(operation) sent no query")
        let pairs = VaporFormSemantics.parse(query)
        return ObservedQuery(
            operation: operation,
            path: request.url?.path ?? "<none>",
            keys: Set(pairs.map(\.name)),
            measuresOccurrences: pairs.filter { $0.name == "measures" }.count,
            statusOccurrences: pairs.filter { $0.name == "status" }.count,
            categoryOccurrences: pairs.filter { $0.name == "category" }.count,
            eventNameOccurrences: pairs.filter { $0.name == "event_name" }.count
        )
    }

    @Test("G3a · each operation's key set and multiplicity match the contract")
    func wireKeysPerOperation() async throws {
        let stub = StubURLProtocol.Session()
        let facade = try MetricsFixtures.makeFacade(stub: stub)

        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("summary_team_all_scope"))
        _ = try await facade.metricsSummary(
            measures: [.feedbackCount, .voteCount, .commentCount],
            dateFrom: Self.windowStart,
            dateTo: Self.windowEnd,
            status: [.pending, .approved],
            category: [.bugReport, .improvement],
            eventName: "checkout_completed"
        )

        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("timeseries_daily"))
        _ = try await facade.metricsTimeseries(
            measures: [.feedbackCount, .eventCount],
            granularity: .day,
            dateFrom: Self.windowStart,
            dateTo: Self.windowEnd,
            status: [.pending, .approved],
            category: [.bugReport, .improvement],
            eventName: "checkout_completed"
        )

        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("breakdown_event_name_with_overflow"))
        _ = try await facade.metricsBreakdown(
            measures: [.eventCount, .uniqueEventUsers],
            dimension: .eventName,
            granularity: .week,
            dateFrom: Self.windowStart,
            dateTo: Self.windowEnd,
            status: [.pending, .approved],
            category: [.bugReport, .improvement],
            eventName: "checkout_completed"
        )

        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("events_page"))
        _ = try await facade.metricsEvents(
            eventName: "checkout_completed",
            dateFrom: Self.windowStart,
            dateTo: Self.windowEnd,
            page: 2,
            perPage: 50
        )

        #expect(stub.recordedRequests.count == 4)

        let observed = [
            try observe(operation: "summary", stub: stub, at: 0),
            try observe(operation: "timeseries", stub: stub, at: 1),
            try observe(operation: "breakdown", stub: stub, at: 2),
            try observe(operation: "events", stub: stub, at: 3),
        ]

        let windowKeys: Set<String> = ["date_from", "date_to"]
        let filterKeys: Set<String> = ["status", "category", "event_name"]
        let expected = [
            ObservedQuery(
                operation: "summary", path: "/api/v1/metrics/summary",
                keys: Set(["measures"]).union(filterKeys).union(windowKeys),
                measuresOccurrences: 1, statusOccurrences: 1,
                categoryOccurrences: 1, eventNameOccurrences: 1
            ),
            ObservedQuery(
                operation: "timeseries", path: "/api/v1/metrics/timeseries",
                keys: Set(["measures", "granularity"]).union(filterKeys).union(windowKeys),
                measuresOccurrences: 1, statusOccurrences: 1,
                categoryOccurrences: 1, eventNameOccurrences: 1
            ),
            ObservedQuery(
                operation: "breakdown", path: "/api/v1/metrics/breakdown",
                keys: Set(["measures", "granularity", "dimension"]).union(filterKeys).union(windowKeys),
                measuresOccurrences: 1, statusOccurrences: 1,
                categoryOccurrences: 1, eventNameOccurrences: 1
            ),
            ObservedQuery(
                operation: "events", path: "/api/v1/metrics/events",
                keys: ["event_name", "date_from", "date_to", "page", "per_page"],
                measuresOccurrences: 0, statusOccurrences: 0,
                categoryOccurrences: 0, eventNameOccurrences: 1
            ),
        ]
        #expect(observed == expected)
    }

    @Test("G3b · list parameters are comma-joined values, and the dates are ISO-8601 instants")
    func commaJoinedValuesAndInstantDates() throws {
        let items = try SwiftlyFeedback.metricsQueryItems(
            measures: [.feedbackCount, .voteCount, .commentCount],
            granularity: .day,
            dimension: .status,
            dateFrom: Self.windowStart,
            dateTo: Self.windowEnd,
            days: nil,
            status: [.pending, .approved],
            category: [.bugReport, .improvement],
            eventName: "checkout_completed"
        )
        // ⚠️ NOT `Dictionary(uniqueKeysWithValues:)`. That initializer TRAPS on a duplicate
        // key, and a duplicate key is exactly the defect this leg exists to catch — measured:
        // against a build that emits three `measures=` parameters the runner died with no red
        // assertion at all. Joining duplicates makes the same defect a value mismatch.
        let byName = Dictionary(
            items.map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { "\($0)|\($1)" }
        )

        #expect(byName["measures"] == "feedback_count,vote_count,comment_count")
        #expect(byName["status"] == "pending,approved")
        #expect(byName["category"] == "bug_report,improvement")
        #expect(byName["event_name"] == "checkout_completed")
        #expect(byName["granularity"] == "day")
        #expect(byName["dimension"] == "status")

        // 🔴 ISO-8601 INSTANTS, not `yyyy-MM-dd`. The bare-date mistake is silent at 200.
        let dateFrom = try #require(byName["date_from"])
        let dateTo = try #require(byName["date_to"])
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        #expect(parser.date(from: dateFrom) == Self.windowStart)
        #expect(parser.date(from: dateTo) == Self.windowEnd)
        #expect(dateFrom.contains("T"))
        #expect(dateFrom.count > 10, "a bare yyyy-MM-dd is 10 characters and is the wrong shape")
    }

    @Test("G3c · the three local refusals fail fast rather than paying a round trip")
    func localRefusals() throws {
        // `days` with the date pair is METRICS_CONFLICTING_WINDOW_PARAMS on the wire.
        #expect(throws: SwiftlyFeedbackError.self) {
            _ = try SwiftlyFeedback.metricsQueryItems(
                measures: [.feedbackCount], dateFrom: Self.windowStart, dateTo: nil,
                days: 30, status: nil, category: nil, eventName: nil
            )
        }
        // An inverted window.
        #expect(throws: SwiftlyFeedbackError.self) {
            _ = try SwiftlyFeedback.metricsQueryItems(
                measures: [.feedbackCount], dateFrom: Self.windowEnd, dateTo: Self.windowStart,
                days: nil, status: nil, category: nil, eventName: nil
            )
        }
        // `days` alone is fine, and travels as an integer.
        let daysOnly = try SwiftlyFeedback.metricsQueryItems(
            measures: [.feedbackCount], dateFrom: nil, dateTo: nil,
            days: 30, status: nil, category: nil, eventName: nil
        )
        #expect(daysOnly.first(where: { $0.name == "days" })?.value == "30")

        // `per_page` is clamped locally to 1...200 — a convenience only; the server answers
        // an out-of-range value with a 400, never a clamp.
        let clampedHigh = try SwiftlyFeedback.metricsQueryItems(
            measures: [], dateFrom: nil, dateTo: nil, days: nil,
            status: nil, category: nil, eventName: nil, page: 1, perPage: 5_000
        )
        let clampedLow = try SwiftlyFeedback.metricsQueryItems(
            measures: [], dateFrom: nil, dateTo: nil, days: nil,
            status: nil, category: nil, eventName: nil, page: 1, perPage: 0
        )
        #expect(clampedHigh.first(where: { $0.name == "per_page" })?.value == "200")
        #expect(clampedLow.first(where: { $0.name == "per_page" })?.value == "1")
    }
}

// MARK: - G4 · the two error bodies, and the four new cases

@Suite("MetricsErrorMap")
struct MetricsErrorMapTests {

    private func thrownError(status: Int, body: Data) async throws -> SwiftlyFeedbackError {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: body, statusCode: status)
        do {
            let _: MetricSummary = try await client.get(path: "metrics/summary", queryItems: [])
            Issue.record("Status \(status) did not throw")
            throw SwiftlyFeedbackError.invalidResponse
        } catch let error as SwiftlyFeedbackError {
            return error
        }
    }

    /// One `enveloped` row, selected **by content** — never by index.
    ///
    /// This file used to reach for `row("enveloped", 0)` and `row("enveloped", 2)`
    /// while the helper below already said rows are selected by content. That was the
    /// last positional coupling to this corpus in any of the six lanes, and it became
    /// load-bearing the moment `enveloped` stopped being a hand-written four and
    /// became a total cover of the 17 wire tokens.
    ///
    /// `hasField` disambiguates the one token that legitimately appears twice —
    /// `METRICS_CUSTOM_EVENTS_REQUIRE_PRO`, once with `field` and once without. Every
    /// other token matches exactly one row, and the count assertion reds on an
    /// ambiguous selector rather than silently taking whichever row sorts first.
    private func envelopedRow(code: String, hasField: Bool? = nil) throws -> Data {
        let corpus = try MetricsFixtures.errorCorpus()
        let rows = try #require(corpus["enveloped"] as? [[String: Any]])
        let matches = rows.filter {
            guard let body = $0["error"] as? [String: Any],
                  body["code"] as? String == code else { return false }
            guard let hasField else { return true }
            return (body["field"] != nil) == hasField
        }
        #expect(matches.count == 1, "\(code) selected \(matches.count) enveloped rows, not one.")
        return try JSONSerialization.data(withJSONObject: try #require(matches.first))
    }

    /// The `middleware` section's rows, each `{http_status, source, body}`.
    private func middlewareRows() throws -> [[String: Any]] {
        let corpus = try MetricsFixtures.errorCorpus()
        return try #require(corpus["middleware"] as? [[String: Any]])
    }

    /// One shared-layer row, selected **by content** — never by index.
    ///
    /// The corpus used to be bare bodies with no status, so this file paired rows to
    /// statuses by index against `C6`'s prose (`row("middleware", 1)` at a typed 403).
    /// Each row now carries its own `http_status`, derived by the generator from the
    /// server source line the `reason` occurs on, so the status is read off the row and
    /// the row is found by its reason.
    private func middlewareRow(reasonContains fragment: String) throws -> (body: Data, status: Int) {
        let matches = try middlewareRows().filter {
            let body = $0["body"] as? [String: Any]
            let reason = body?["reason"] as? String ?? ""
            return reason.contains(fragment)
        }
        #expect(matches.count == 1, "\(fragment) selected \(matches.count) rows, not one.")
        let match = try #require(matches.first)
        let body = try #require(match["body"])
        let status = try #require(match["http_status"] as? Int)
        return (try JSONSerialization.data(withJSONObject: body), status)
    }

    @Test("G4a · the corpus carries exactly two shapes of `error`, object and boolean")
    func errorShapeCardinalityIsTwo() throws {
        let corpus = try MetricsFixtures.errorCorpus()
        let enveloped = try #require(corpus["enveloped"] as? [[String: Any]])
        let middleware = try #require(corpus["middleware"] as? [[String: Any]])
        #expect(!enveloped.isEmpty && !middleware.isEmpty, "the corpus sections must be populated")

        // Middleware rows WRAP their body; enveloped rows ARE the body.
        let bodies = enveloped + middleware.compactMap { $0["body"] as? [String: Any] }
        #expect(bodies.count == enveloped.count + middleware.count, "every middleware row has a body")

        var shapes: Set<String> = []
        for body in bodies {
            let value = try #require(body["error"], "every error row carries an `error` key")
            if value is [String: Any] {
                shapes.insert("object")
            } else if value is Bool || value is NSNumber {
                shapes.insert("boolean")
            } else {
                shapes.insert("other:\(type(of: value))")
            }
        }
        // A one-shape decoder passes any presence oracle. The cardinality is the gate.
        #expect(shapes == ["object", "boolean"])
        #expect(shapes.count == 2)
    }

    @Test("G4b · 403 in both shapes maps to two different cases")
    func forbiddenSplit() async throws {
        // Shape A, `METRICS_MEASURE_REQUIRES_BEARER` — selected by its token.
        let measure = try await thrownError(
            status: 403, body: try envelopedRow(code: "METRICS_MEASURE_REQUIRES_BEARER")
        )
        #expect(measure == .measureNotAvailable(
            measure: "mrr_sum",
            message: "Measure 'mrr_sum' is not available on the API-key surface. Use the authenticated project metrics endpoint."
        ))

        // Shape B, the suspension refusal — selected by reason, driven by its own status.
        let suspendedRow = try middlewareRow(reasonContains: "suspended")
        #expect(suspendedRow.status == 403)
        let suspended = try await thrownError(status: suspendedRow.status, body: suspendedRow.body)
        #expect(suspended == .forbidden(message: "This project is suspended."))

        // The two must not collapse — that collapse is the named failure mode.
        #expect(measure != suspended)
    }

    @Test("G4c · 402 in both shapes maps to two different cases, and the shipped pin is unmoved")
    func tierSplit() async throws {
        // Shape A with the tier code — the field-carrying one of the two rows that
        // share this token.
        let tier = try await thrownError(
            status: 402,
            body: try envelopedRow(code: "METRICS_CUSTOM_EVENTS_REQUIRE_PRO", hasField: true)
        )
        #expect(tier == .tierUpgradeRequired(
            code: .customEventsRequirePro,
            message: "Breaking down metrics by event name requires the Pro plan."
        ))

        // Shape B — the feedback / project / member caps. UNCHANGED behaviour.
        let cap = try await thrownError(status: 402, body: Data(#"{"error":true,"reason":"Upgrade required"}"#.utf8))
        #expect(cap == .feedbackLimitReached(message: "Upgrade required"))

        #expect(tier != cap)
    }

    @Test("G4d · 429 maps to .rateLimited and carries the middleware's prose")
    func rateLimited() async throws {
        // The rate-limiter's row, selected by reason rather than by index.
        let rateLimit = try middlewareRow(reasonContains: "Too many requests")
        #expect(rateLimit.status == 429)
        let error = try await thrownError(status: rateLimit.status, body: rateLimit.body)
        #expect(error == .rateLimited(message: "Too many requests. Try again later."))
    }

    @Test("G4e · an unrecognised 402 code stays a cap refusal rather than a decode failure")
    func unknownCodeDegradesGracefully() async throws {
        let body = Data(#"{"error":{"code":"METRICS_SOMETHING_NEW","message":"Future token"},"timestamp":"x"}"#.utf8)
        // Not a hand-written CONTRACT fixture — a deliberately-unknown token, which by
        // definition cannot be in a corpus generated from today's server.
        let error = try await thrownError(status: 402, body: body)
        #expect(error == .feedbackLimitReached(message: "Future token"))
        #expect(MetricsErrorCode(rawValue: "METRICS_SOMETHING_NEW") == nil)
    }

    @Test("G4f · MetricsErrorCode is set-equal to the corpus's 17 wire tokens")
    func vocabularyIsSetEqual() throws {
        let corpus = try MetricsFixtures.errorCorpus()
        let vocabulary = try #require(corpus["vocabulary"] as? [[String: Any]])
        #expect(!vocabulary.isEmpty)

        let corpusTokens = Set(vocabulary.compactMap { $0["wire_token"] as? String })
        let declared = Set(MetricsErrorCode.allCases.map(\.rawValue))

        // Set equality, not a count: a count cannot see a misspelling that keeps the count.
        #expect(declared == corpusTokens)
        #expect(declared.count == 17)
        // Every token round-trips through the enum.
        #expect(corpusTokens.allSatisfy { MetricsErrorCode(rawValue: $0) != nil })
    }
}

// MARK: - G5 · `values` and `properties` are not key-mangled

@Suite("MetricsDecoding")
struct MetricsDecodingTests {

    @Test("G5a · a breakdown's values keep the server's snake_case tokens, and are sparse")
    func breakdownValuesAreVerbatimAndSparse() async throws {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("breakdown_event_name_with_overflow"))

        let breakdown: MetricBreakdown = try await client.get(
            path: "metrics/breakdown", queryItems: []
        )
        #expect(breakdown.dimension == .eventName)
        #expect(breakdown.items.count == 2)

        let full = try #require(breakdown.items.first { !$0.isOverflow })
        let overflow = try #require(breakdown.items.first { $0.isOverflow })

        // Derived from the corpus's own meta.measures — never retyped here.
        let requested = Set(breakdown.meta.measures)
        #expect(requested == ["event_count", "unique_event_users"])

        // Both directions: an extra key and a second absence are equally visible.
        #expect(Set(full.values.keys) == requested)
        #expect(Set(overflow.values.keys) == requested.subtracting(["unique_event_users"]))

        // 🔴 The sparsity rule. `values["unique_event_users"]!` would crash here, on a row
        // that is reachable in production.
        #expect(overflow[.uniqueEventUsers] == nil)
        #expect(overflow[.eventCount] == 402)
        #expect(full[.uniqueEventUsers] == 317)

        // The camelCase image must NOT bind — that is what a hand-rolled decoder would do.
        #expect(overflow.values["uniqueEventUsers"] == nil)
        #expect(full.values["eventCount"] == nil)
    }

    @Test("G5b · an event row's properties survive verbatim, un-camelCased")
    func eventPropertiesAreVerbatim() async throws {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("events_page"))

        let page: MetricEventList = try await client.get(path: "metrics/events", queryItems: [])

        // 🔴 TWO meta blocks. A model putting the metrics block under `meta` decodes nothing.
        #expect(page.meta.page == 2)
        #expect(page.meta.perPage == 50)
        #expect(page.meta.total == 137)
        #expect(page.meta.totalPages == 3)
        #expect(page.metrics.retentionWindowDays == 30)
        #expect(page.metrics.granularity == nil, "granularity is ABSENT on the event feed, never null")

        #expect(page.items.count == 2)
        let first = try #require(page.items.first)
        #expect(Set(first.properties?.keys ?? [:].keys) == ["checkout_step", "utm_source"])
        #expect(first.properties?["checkout_step"] == "payment")
        #expect(first.properties?["checkoutStep"] == nil)
        #expect(page.items.last?.properties == nil)
        #expect(page.items.last?.createdAt == nil)
    }

    @Test("G5c · granularity is optional per SURFACE — absent on summary, present on breakdown")
    func granularityOptionalityPerSurface() async throws {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)

        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("summary_free_scoped_and_clamped"))
        let summary: MetricSummary = try await client.get(path: "metrics/summary", queryItems: [])
        #expect(summary.meta.granularity == nil)
        #expect(summary.meta.eventScope == .predefinedOnly)
        #expect(summary.meta.retentionClamped == true)
        #expect(summary.meta.retentionWindowDays == 30)
        // A scoped, clamped answer is a SUCCESS carrying typed properties, not an error.
        #expect(summary[.feedbackCount] == 10)
        #expect(summary[.sdkUserCount] == nil)

        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("breakdown_event_name_with_overflow"))
        let breakdown: MetricBreakdown = try await client.get(path: "metrics/breakdown", queryItems: [])
        #expect(breakdown.meta.granularity == .day, "breakdown carries all nine meta fields")
        #expect(breakdown.meta.truncated == true)
    }

    @Test("G5d · a timeseries keeps its zero-valued buckets rather than omitting them")
    func timeseriesKeepsEmptyBuckets() async throws {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("timeseries_daily"))

        let series: MetricSeries = try await client.get(path: "metrics/timeseries", queryItems: [])
        #expect(series.meta.granularity == .day)
        #expect(series.series.map(\.bucket) == ["2023-11-12", "2023-11-13", "2023-11-14"])
        #expect(series.series.map { $0[.eventCount] } == [91, 0, 44])
        #expect(series.series.allSatisfy { !$0.values.isEmpty })
    }

    @Test("G5e · the full nine-measure summary binds every token verbatim")
    func fullMeasureSetBinds() async throws {
        let stub = StubURLProtocol.Session()
        let client = try MetricsFixtures.makeClient(stub: stub)
        stub.enqueueResponse(data: try MetricsFixtures.metricsRow("summary_team_all_scope"))

        let summary: MetricSummary = try await client.get(path: "metrics/summary", queryItems: [])
        #expect(Set(summary.values.keys) == Set(MetricMeasure.allCases.map(\.rawValue)))
        #expect(summary.meta.resolvedMeasures.count == MetricMeasure.allCases.count)
        #expect(summary[.mrrSum] == 18432.5)
        #expect(summary[.usersWithMrr] == 447)
    }
}

// MARK: - G6 · every error case is reflexively equal, derived from the source

@Suite("SwiftlyFeedbackErrorAlgebra")
struct SwiftlyFeedbackErrorAlgebraTests {

    /// One representative per case. `==` is hand-written with a `default: return false`, so
    /// a case whose arm was forgotten compares unequal to ITSELF and fails here.
    private static let allRepresentatives: [SwiftlyFeedbackError] = [
        .invalidResponse,
        .badRequest(message: "b"),
        .unauthorized,
        .invalidApiKey,
        .notFound,
        .conflict,
        .serverError(statusCode: 500),
        .networkError(underlying: URLError(.notConnectedToInternet)),
        .decodingError(underlying: URLError(.cannotDecodeRawData)),
        .feedbackLimitReached(message: "f"),
        .tierUpgradeRequired(code: .customEventsRequirePro, message: "t"),
        .measureNotAvailable(measure: "mrr_sum", message: "m"),
        .forbidden(message: "x"),
        .rateLimited(message: "r"),
    ]

    @Test("G6a · every case equals itself")
    func everyCaseIsReflexive() {
        let notReflexive = Self.allRepresentatives.filter { !($0 == $0) }
        #expect(notReflexive.isEmpty,
                "these cases have no `==` arm: \(notReflexive.map { String(describing: $0) })")
    }

    @Test("G6b · the representative list covers every case declared in the source")
    func representativeCountMatchesTheSource() throws {
        let source = try WorkspaceSourceTree.sdkSource(
            "Sources/SwiftlyFeedbackKit/Networking/SwiftlyFeedbackError.swift"
        )
        let stripped = CommentStripper.strip(source)
        #expect(stripped.contains("public enum SwiftlyFeedbackError"),
                "the stripper ate the declaration — every count below would be vacuous")

        let body = try #require(
            stripped.components(separatedBy: "public enum SwiftlyFeedbackError").dropFirst().first?
                .components(separatedBy: "public var errorDescription").first
        )
        let declared = body.components(separatedBy: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("case ")
        }
        #expect(declared.count == 14, "found \(declared.count) case declarations: \(declared)")
        #expect(Self.allRepresentatives.count == declared.count)
    }

    @Test("G6c · the four new cases are distinct from each other and from the shipped ten")
    func newCasesAreDistinct() {
        // A collapse — one `.forbidden(code:)` standing in for both 403s, say — would show
        // up as two representatives comparing equal.
        var seenEqualPairs: [String] = []
        for (i, lhs) in Self.allRepresentatives.enumerated() {
            for rhs in Self.allRepresentatives[(i + 1)...] where lhs == rhs {
                seenEqualPairs.append("\(lhs) == \(rhs)")
            }
        }
        #expect(seenEqualPairs.isEmpty, "distinct cases compared equal: \(seenEqualPairs)")
    }

    @Test("G6d · every case resolves a non-empty errorDescription, and every symbol it names has a catalog row")
    func everyCaseIsLocalized() throws {
        // ⚠️ MEASURED, and it decides the shape of this gate: under `swift test` the String
        // Catalog does NOT resolve — SwiftPM ships the raw `.xcstrings` into the bundle and
        // compiles no `.strings`, so every `String(localized:)` returns its own KEY. An
        // assertion that a description is not its key can therefore never pass here, and one
        // written with `String(localized:locale:)` would read `en` and pass over nothing.
        // The runtime leg is limited to what is true in this runner; the "right row exists"
        // half is asserted against the catalog as DATA, which is true on any machine.
        let descriptions = Self.allRepresentatives.map { $0.errorDescription ?? "" }
        #expect(descriptions.allSatisfy { !$0.isEmpty })

        // Every catalog key, as the symbol `xcstringstool` generates for it.
        let data = try Data(contentsOf: StringCatalogReader.catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: Any])
        var symbolToKey: [String: String] = [:]
        for key in strings.keys {
            let parts = key.components(separatedBy: ".")
            let symbol = ([parts[0]] + parts.dropFirst().map { part in
                part.prefix(1).uppercased() + part.dropFirst()
            }).joined()
            symbolToKey[symbol] = key
        }
        #expect(symbolToKey.count == strings.count, "two keys collided onto one symbol")

        // Every symbol the error map actually names, read from the comment-stripped source.
        let source = CommentStripper.strip(try WorkspaceSourceTree.sdkSource(
            "Sources/SwiftlyFeedbackKit/Networking/SwiftlyFeedbackError.swift"
        ))
        #expect(source.contains("errorDescription"), "the stripper ate the file")
        let referenced = source.components(separatedBy: "String(localized: .").dropFirst().compactMap {
            $0.prefix { $0.isLetter || $0.isNumber }.description
        }
        // The denominator: fourteen cases, of which two carry a plain message-only arm and
        // twelve name a symbol — a zero here would make the loop below vacuous.
        #expect(referenced.count >= 14, "found only \(referenced.count) localized symbols")

        let unbacked = referenced.filter { symbolToKey[$0] == nil }
        #expect(unbacked.isEmpty, "these symbols have no catalog row: \(Set(unbacked).sorted())")

        // The four new arms specifically, and their English values, read as data.
        let newSymbols = [
            "errorTierUpgradeRequiredMessage",
            "errorMeasureNotAvailableMessage",
            "errorForbiddenMessage",
            "errorRateLimitedMessage",
        ]
        #expect(newSymbols.allSatisfy { referenced.contains($0) },
                "an arm was added without naming its own key")
        let englishValues = try newSymbols.map { symbol -> String in
            let key = try #require(symbolToKey[symbol], "no catalog row for \(symbol)")
            return try StringCatalogReader.englishValue(for: key)
        }
        #expect(Set(englishValues).count == 4, "the four fallbacks must be four different strings")
    }
}

// MARK: - G7 · the three predefined names exist once

@Suite("MetricsPredefinedNames")
struct MetricsPredefinedNameTests {

    @Test("G7 · PredefinedEventName, PredefinedView and the corpus agree exactly")
    func predefinedNamesAgree() throws {
        let metricsSide = Set(PredefinedEventName.allCases.map(\.rawValue))
        let trackingSide = Set(PredefinedView.allCases.map(\.rawValue))

        #expect(metricsSide == trackingSide)
        #expect(metricsSide.count == 3)

        // The corpus's own predefined name, from the generated event fixture.
        let events = try #require(
            try JSONSerialization.jsonObject(
                with: MetricsFixtures.corpusData("event-wire-corpus.json")
            ) as? [[String: Any]]
        )
        let corpusNames = Set(events.compactMap { $0["event_name"] as? String })
        #expect(!corpusNames.isEmpty)
        #expect(corpusNames.isSubset(of: metricsSide),
                "the generated event corpus names \(corpusNames.sorted())")

        // Exact and CASE-SENSITIVE: a differing case is a custom event, and lands behind the
        // Pro wall. This is the cheapest way for a typo to cost a customer their free data.
        #expect(!metricsSide.contains("Feedback_List"))
        #expect(PredefinedEventName(.feedbackDetail) == .feedbackDetail)
        #expect(PredefinedEventName.submitFeedback.predefinedView == .submitFeedback)
    }
}

// MARK: - G8 / G10 / G11 · source-level gates

@Suite("MetricsSourceGates")
struct MetricsSourceGateTests {

    /// Every `.swift` file under the package's `Sources/` and `Tests/`, comment-stripped.
    ///
    /// 🔴 Scoped to the package. `docs/` writes the forbidden spellings in PROSE, saying they
    /// must not exist; a gate that swept the docs tree would red on the paragraph describing
    /// itself.
    private static func packageSwiftFiles() throws -> [(path: String, stripped: String)] {
        let root = WorkspaceSourceTree.packageRoot
        var results: [(String, String)] = []
        for subtree in ["Sources", "Tests"] {
            let directory = root.appendingPathComponent(subtree)
            let enumerator = try #require(
                FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil)
            )
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let text = try String(contentsOf: url, encoding: .utf8)
                results.append((url.path, CommentStripper.strip(text)))
            }
        }
        return results
    }

    @Test("G8 · no bucket_start / bucketStart anywhere in the package, and the scan looked")
    func noBucketStartField() throws {
        let files = try Self.packageSwiftFiles()

        // The denominator. Zero hits over zero files is not a pass.
        #expect(files.count > 40, "scanned only \(files.count) files")
        let totalLines = files.reduce(0) { $0 + $1.stripped.components(separatedBy: "\n").count }
        #expect(totalLines > 1_000, "only \(totalLines) lines survived stripping")
        // The stripper is not eating the code it is supposed to search.
        #expect(files.contains { $0.stripped.contains("struct MetricSeriesPoint") })

        let offenders = files.filter {
            $0.stripped.contains("bucket_start") || $0.stripped.contains("bucketStart")
        }
        #expect(offenders.isEmpty, "bucket_start appears in: \(offenders.map(\.path))")

        // The paired positive: `bucket` itself IS there, so the needle can match something.
        #expect(files.contains { $0.stripped.contains("let bucket: String") })
    }

    @Test("G10 · no new dependency, no logged secret, no AppLogger")
    func noDependencyNoSecretNoAppLogger() throws {
        let files = try Self.packageSwiftFiles()
        #expect(files.count > 40)

        // (a) The manifest is a PUBLISHED one and declares no dependencies.
        let manifest = try String(
            contentsOf: WorkspaceSourceTree.packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        #expect(manifest.contains("name: \"SwiftlyFeedbackKit\""), "Package.swift was not read")
        #expect(!CommentStripper.strip(manifest).contains(".package("))

        // (b) No SDKLogger call may carry the API key. Scanned per call site, not per file.
        var loggerCallSites = 0
        var leaking: [String] = []
        for file in files {
            for line in file.stripped.components(separatedBy: "\n") where line.contains("SDKLogger.") {
                loggerCallSites += 1
                if line.contains("apiKey") { leaking.append("\(file.path): \(line.trimmingCharacters(in: .whitespaces))") }
            }
        }
        #expect(loggerCallSites > 10, "found only \(loggerCallSites) SDKLogger call sites")
        #expect(leaking.isEmpty, "an API key reaches the log at: \(leaking)")

        // (c) AppLogger is the Admin app's; it must not appear here.
        let appLogger = files.filter { $0.stripped.contains("AppLogger") }
        #expect(appLogger.isEmpty, "AppLogger in: \(appLogger.map(\.path))")

        // (d) Views/ is non-empty — the scan really covers the tree the absence is about.
        let viewFiles = files.filter { $0.path.contains("/Sources/SwiftlyFeedbackKit/Views/") }
        #expect(viewFiles.count > 5, "found \(viewFiles.count) view files")
    }

    @Test("G11 · every public property of Metrics.swift has an invertible snake_case image")
    func metricsPropertyNamesAreInvertible() throws {
        let source = try WorkspaceSourceTree.sdkSource(
            "Sources/SwiftlyFeedbackKit/Models/Metrics.swift"
        )
        let stripped = CommentStripper.strip(source)
        #expect(stripped.contains("public struct MetricsMeta"), "the stripper ate the file")

        let names: [String] = stripped.components(separatedBy: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("public let ") else { return nil }
            return trimmed.dropFirst("public let ".count)
                .components(separatedBy: ":").first?
                .trimmingCharacters(in: .whitespaces)
        }
        // The denominator: a typo in the prefix would make this loop find nothing and pass.
        #expect(names.count >= 20, "found only \(names.count) public properties: \(names)")
        #expect(names.contains("retentionWindowDays"))

        // 🔴 The ACRONYM RUN is the whole defect, and the naive round trip below cannot see
        // it. Measured while arming this gate: a hand-rolled `toSnake` that emits `_` before
        // every capital turns `retentionWindowDAYS` into `retention_window_d_a_y_s`, and the
        // matching `fromSnake` turns that straight back into `retentionWindowDAYS` — the pair
        // is self-consistent and reports the name as invertible. Foundation's real
        // `.convertToSnakeCase` does NOT split a run: it emits `retention_window_days`, which
        // `.convertFromSnakeCase` reads back as `retentionWindowDays`, a property that does
        // not exist. So the falsifiable leg is the run itself; the round trip is corroboration
        // over the names the run test already cleared.
        let acronymRuns = names.filter {
            $0.range(of: "[A-Z]{2}", options: .regularExpression) != nil
        }
        #expect(acronymRuns.isEmpty,
                "consecutive capitals never survive the snake_case round trip: \(acronymRuns)")

        func toSnake(_ name: String) -> String {
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
        func fromSnake(_ token: String) -> String {
            let parts = token.components(separatedBy: "_")
            return ([parts[0]] + parts.dropFirst().map { $0.capitalized }).joined()
        }

        // Corroboration only — sound exactly because `acronymRuns` is already empty, which is
        // the condition under which this replica and the real strategy agree.
        let nonInvertible = names.filter { fromSnake(toSnake($0)) != $0 }
        #expect(nonInvertible.isEmpty, "these names cannot round-trip: \(nonInvertible)")
    }
}

// MARK: - G9 · the String Catalog, in all eleven locales

@Suite("MetricsStringCatalog")
struct MetricsStringCatalogTests {

    private static let newKeys = [
        "error.forbidden.message",
        "error.measureNotAvailable.message",
        "error.rateLimited.message",
        "error.tierUpgradeRequired.message",
    ]

    private static func catalog() throws -> [String: [String: Any]] {
        let data = try Data(contentsOf: StringCatalogReader.catalogURL)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(root["strings"] as? [String: [String: Any]])
    }

    /// The value for one locale, or `nil` when the row is absent or empty.
    ///
    /// Three shipped rows are PLURAL entries carrying `variations` instead of a
    /// `stringUnit`; a helper that knows only `stringUnit` reports them as empty English and
    /// the census reds on a catalog that is in fact clean. Their plural arms are joined so
    /// an empty one is still visible.
    private static func value(_ entry: [String: Any], locale: String) -> String? {
        guard
            let localizations = entry["localizations"] as? [String: Any],
            let localized = localizations[locale] as? [String: Any]
        else { return nil }

        if let unit = localized["stringUnit"] as? [String: Any],
           let value = unit["value"] as? String,
           !value.isEmpty {
            return value
        }
        if let variations = localized["variations"] as? [String: Any],
           let plural = variations["plural"] as? [String: Any] {
            let arms = plural.keys.sorted().compactMap { form -> String? in
                guard
                    let armEntry = plural[form] as? [String: Any],
                    let unit = armEntry["stringUnit"] as? [String: Any],
                    let value = unit["value"] as? String,
                    !value.isEmpty
                else { return nil }
                return "\(form)=\(value)"
            }
            guard arms.count == plural.count, !arms.isEmpty else { return nil }
            return arms.joined(separator: "|")
        }
        return nil
    }

    @Test("G9a · the four new keys carry every shipped locale, non-empty and not the English")
    func newKeysAreFullyLocalized() throws {
        let strings = try Self.catalog()

        // The locale set is DERIVED from a shipped sibling in the same family, never typed.
        let sibling = try #require(strings["error.badRequest.message"])
        let siblingLocalizations = try #require(sibling["localizations"] as? [String: Any])
        let locales = Set(siblingLocalizations.keys)
        #expect(locales.count == 11, "the SDK ships \(locales.count) locales: \(locales.sorted())")
        #expect(locales.contains("en"))

        var missing: [String] = []
        var untranslated: [String] = []
        for key in Self.newKeys {
            let entry = try #require(strings[key], "the catalog has no \(key)")
            #expect(entry["extractionState"] as? String == "manual",
                    "\(key) is harvested, not manual — a harvested row is a bug to delete")
            let english = try #require(Self.value(entry, locale: "en"), "\(key) has no en value")
            for locale in locales.sorted() {
                guard let localized = Self.value(entry, locale: locale) else {
                    missing.append("\(key)/\(locale)")
                    continue
                }
                // ⚠️ Non-vacuity. `String(localized:locale:)` does NOT select the .lproj, so
                // a per-locale assertion written with it reads `en` and passes over nothing.
                // Reading the catalog as data and requiring a DIFFERENT string is the check
                // that can actually fail.
                if locale != "en", localized == english {
                    untranslated.append("\(key)/\(locale)")
                }
            }
        }
        #expect(missing.isEmpty, "absent localizations: \(missing)")
        #expect(untranslated.isEmpty, "these still hold the English string: \(untranslated)")
    }

    @Test("G9b · the catalog stays reconcile-clean: no empty en, no harvested row")
    func catalogRemainsClean() throws {
        let strings = try Self.catalog()
        #expect(strings.count == 115, "the catalog holds \(strings.count) keys")

        let emptyEnglish = strings.filter { Self.value($0.value, locale: "en") == nil }
        let harvested = strings.filter { ($0.value["extractionState"] as? String) != "manual" }

        // The measured branch-point baseline is ZERO of each; this asserts the diff, not an
        // absolute that a sibling branch could move underneath.
        #expect(emptyEnglish.isEmpty, "empty en values: \(emptyEnglish.keys.sorted())")
        #expect(harvested.isEmpty, "non-manual rows: \(harvested.keys.sorted())")
    }

    @Test("G9c · the new values carry no interpolation, so neither catalog trap is reachable")
    func newValuesAreInterpolationFree() throws {
        let strings = try Self.catalog()
        for key in Self.newKeys {
            let entry = try #require(strings[key])
            let english = try #require(Self.value(entry, locale: "en"))
            // An interpolated `%` doubles to `%%` in the harvested key, and the harvested
            // spelling is the live one — the trap is only avoidable by having no format
            // specifier at all.
            #expect(!english.contains("%"), "\(key) carries a format specifier")
            #expect(!english.contains("@"), "\(key) carries a format specifier")
        }
    }
}
