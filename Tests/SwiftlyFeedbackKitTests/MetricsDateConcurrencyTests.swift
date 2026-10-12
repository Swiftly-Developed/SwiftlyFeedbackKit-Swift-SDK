import Foundation
import Testing
@testable import SwiftlyFeedbackKit

/// Concurrent metrics windows must each encode the instant they were given.
///
/// `ISO8601DateFormatter` is a class and is not safe to share across tasks. A single
/// stored formatter behind `metricsQueryItems` swaps or corrupts dates when a load
/// test issues windows together.
@Suite("Metrics date concurrency")
struct MetricsDateConcurrencyTests {
    private static let early = Date(timeIntervalSince1970: 1_700_000_000)
    private static let late = Date(timeIntervalSince1970: 1_700_086_400)

    @Test func concurrentWindowsKeepTheirOwnInstants() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<160 {
                let date = index.isMultiple(of: 2) ? Self.early : Self.late
                group.addTask {
                    let parser = ISO8601DateFormatter()
                    parser.formatOptions = [.withInternetDateTime]
                    let items = try SwiftlyFeedback.metricsQueryItems(
                        measures: [.eventCount],
                        dateFrom: date,
                        dateTo: date,
                        days: nil,
                        status: nil,
                        category: nil,
                        eventName: nil
                    )
                    let raw = try #require(items.first { $0.name == "date_from" }?.value)
                    let parsed = try #require(parser.date(from: raw))
                    #expect(parsed == date)
                    #expect(raw.contains("T"))
                }
            }
            try await group.waitForAll()
        }
    }

    @Test func concurrentISO8601DecodingKeepsFractionalAndWholeSeconds() async throws {
        let whole = Data(#""2023-11-14T22:13:20Z""#.utf8)
        let fractional = Data(#""2023-11-14T22:13:20.250Z""#.utf8)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<160 {
                let payload = index.isMultiple(of: 2) ? whole : fractional
                let expected = index.isMultiple(of: 2)
                    ? Self.early
                    : Date(timeIntervalSince1970: 1_700_000_000.250)
                group.addTask {
                    let date = try WireCoding.makeDecoder().decode(Date.self, from: payload)
                    #expect(abs(date.timeIntervalSince(expected)) < 0.001)
                }
            }
            try await group.waitForAll()
        }
    }

    /// Concurrent event posts must each carry the attempt and idempotency id they were given.
    @Test func concurrentEventPostsKeepTheirIdempotencyAttempts() async throws {
        let stub = StubURLProtocol.Session()
        let baseURL = try #require(URL(string: "https://stub.invalid/api/v1"))
        let facade = SwiftlyFeedback(
            apiKey: "sf_test_stub_key_not_a_credential",
            userId: "user-under-test",
            baseURL: baseURL,
            session: stub.urlSession
        )
        let idempotencyID = "run-concurrent"
        let count = 24
        let body = Data(
            #"{"id":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE","event_name":"load","user_id":"user-under-test"}"#.utf8
        )
        for _ in 0..<count {
            stub.enqueueResponse(data: body)
        }

        await withTaskGroup(of: Void.self) { group in
            for attempt in 0..<count {
                group.addTask {
                    await facade.trackView(
                        name: "load_test",
                        properties: [
                            "idempotency_id": idempotencyID,
                            "attempt": String(attempt)
                        ]
                    )
                }
            }
        }

        let attempts = stub.recordedRequests.compactMap { request -> Int? in
            guard let data = request.body,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let properties = json["properties"] as? [String: String],
                  properties["idempotency_id"] == idempotencyID,
                  let attempt = properties["attempt"] else { return nil }
            return Int(attempt)
        }
        #expect(Set(attempts) == Set(0..<count))
        #expect(attempts.count == count)
    }
}
