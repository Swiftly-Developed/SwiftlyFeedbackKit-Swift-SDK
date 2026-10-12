//  StubURLProtocol.swift
//  SwiftlyFeedbackKitTests
//
//  QA-UNIT01-FOUNDATION §18 — the SDK test seam (test ID `-08`).
//
//  Purpose
//  -------
//  Drive the SDK's REAL `APIClient` end to end without a server. The seam is the
//  already-shipping `APIClient.init(baseURL:apiKey:userId:session:)` parameter — this
//  file adds no SDK API and requires no SDK source change (§18's binding constraint).
//  Because the stub sits at the URL-loading layer, every test that goes through it runs
//  the client's real header construction, real `JSONEncoder`/`JSONDecoder` (snake-case +
//  ISO-8601) and real status→`SwiftlyFeedbackError` mapping.
//
//  Parallel safety — the trap and the chosen mechanism
//  ---------------------------------------------------
//  `URLProtocol` subclassing is *class*-scoped: there is exactly one `StubURLProtocol`
//  type in the process, so a plain `static var handler` would be overwritten by whichever
//  concurrently-running `@Test` scripted itself last. Two mechanisms were considered:
//
//    * `@TaskLocal` — REJECTED. `URLProtocol.startLoading()` runs on `URLSession`'s own
//      internal queue, not in the calling task's context, so a task-local set by the test
//      does not propagate into the protocol instance.
//
//    * A registry keyed by a per-session UUID carried in a request header — CHOSEN.
//      `Session` mints a UUID, stashes it in the ephemeral configuration's
//      `httpAdditionalHeaders`, and `URLSession` merges that header into every request the
//      protocol instance sees. The script queue and the recorded requests are stored under
//      that key, so concurrent tests never observe one another. The registration itself is
//      scoped to the session (`configuration.protocolClasses`), never
//      `URLProtocol.registerClass`, so the shared `URLSession` is untouched.
//
//  A request that arrives without the key, or with an empty script queue, is FAILED with a
//  distinctive `StubError` rather than silently answered — a misbinding must be loud.
//
//  Fresh `Session` (and therefore a fresh script + fresh recording) per `@Test`. No shared
//  instance, no reset hook, no `static` fixture state.

import Foundation

/// A `URLProtocol` that answers requests from a per-session script and records what it saw.
///
/// Never used directly by tests — go through ``StubURLProtocol/Session``.
final class StubURLProtocol: URLProtocol {

    // MARK: - Nested types

    /// A scripted HTTP answer.
    struct StubbedResponse {
        var data: Data
        var statusCode: Int
        var headers: [String: String]

        init(data: Data = Data(), statusCode: Int = 200, headers: [String: String] = [:]) {
            self.data = data
            self.statusCode = statusCode
            self.headers = headers
        }
    }

    /// What the stub does with the next request on a session.
    enum Outcome {
        case response(StubbedResponse)
        case failure(any Error)
    }

    /// Everything the stub saw about one request.
    struct RecordedRequest {
        let method: String
        let url: URL?
        let headers: [String: String]
        let body: Data?

        /// HTTP header names are case-insensitive; look them up that way.
        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        var path: String? { url?.path }
    }

    /// Failures the stub itself raises. Each means the *test* is mis-wired, not the SDK.
    enum StubError: Error, CustomStringConvertible {
        /// The request carried no session key — `httpAdditionalHeaders` did not survive.
        case unkeyedRequest
        /// The session's script queue was empty when this request arrived.
        case noScriptedOutcome(method: String, url: String)
        /// `HTTPURLResponse` refused the scripted status/URL pair.
        case unconstructableResponse(statusCode: Int)

        var description: String {
            switch self {
            case .unkeyedRequest:
                return "StubURLProtocol: request carried no \(StubURLProtocol.sessionHeaderName) header"
            case .noScriptedOutcome(let method, let url):
                return "StubURLProtocol: no scripted outcome left for \(method) \(url)"
            case .unconstructableResponse(let statusCode):
                return "StubURLProtocol: could not build an HTTPURLResponse with status \(statusCode)"
            }
        }
    }

    /// A test-owned handle: one ephemeral `URLSession` wired to the stub, plus this
    /// session's script queue and request recording.
    ///
    /// Build one per `@Test`, pass ``urlSession`` into `APIClient(… session:)`, and let it
    /// go out of scope — `deinit` deregisters and invalidates.
    final class Session {
        /// The key this session's requests carry, and the registry key for its state.
        let key: String

        /// Hand this to `APIClient.init(baseURL:apiKey:userId:session:)`.
        let urlSession: URLSession

        init() {
            let key = UUID().uuidString
            self.key = key

            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [StubURLProtocol.self]
            configuration.httpAdditionalHeaders = [StubURLProtocol.sessionHeaderName: key]
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            self.urlSession = URLSession(configuration: configuration)

            StubURLProtocol.open(key: key)
        }

        deinit {
            urlSession.invalidateAndCancel()
            StubURLProtocol.close(key: key)
        }

        /// Script the next answer on this session. Outcomes are consumed FIFO.
        func enqueue(_ outcome: Outcome) {
            StubURLProtocol.enqueue(outcome, forKey: key)
        }

        /// Convenience for the common `(Data, statusCode, headers)` case.
        func enqueueResponse(
            data: Data = Data(),
            statusCode: Int = 200,
            headers: [String: String] = ["Content-Type": "application/json"]
        ) {
            enqueue(.response(StubbedResponse(data: data, statusCode: statusCode, headers: headers)))
        }

        /// Script a transport-level failure, so the client's real error path runs.
        func enqueueFailure(_ error: any Error) {
            enqueue(.failure(error))
        }

        /// Every request this session's stub saw, in call order.
        var recordedRequests: [RecordedRequest] {
            StubURLProtocol.recordedRequests(forKey: key)
        }
    }

    // MARK: - Registry (process-global by necessity, keyed per session)

    /// The header `Session` plants via `httpAdditionalHeaders` to identify itself.
    static let sessionHeaderName = "X-Stub-Session"

    nonisolated(unsafe) private static var registryLock = NSLock()
    nonisolated(unsafe) private static var scripts: [String: [Outcome]] = [:]
    nonisolated(unsafe) private static var recordings: [String: [RecordedRequest]] = [:]

    private static func open(key: String) {
        registryLock.lock()
        defer { registryLock.unlock() }
        scripts[key] = []
        recordings[key] = []
    }

    private static func close(key: String) {
        registryLock.lock()
        defer { registryLock.unlock() }
        scripts.removeValue(forKey: key)
        recordings.removeValue(forKey: key)
    }

    private static func enqueue(_ outcome: Outcome, forKey key: String) {
        registryLock.lock()
        defer { registryLock.unlock() }
        scripts[key, default: []].append(outcome)
    }

    private static func dequeueOutcome(forKey key: String) -> Outcome? {
        registryLock.lock()
        defer { registryLock.unlock() }
        guard var queue = scripts[key], !queue.isEmpty else { return nil }
        let next = queue.removeFirst()
        scripts[key] = queue
        return next
    }

    private static func record(_ request: RecordedRequest, forKey key: String) {
        registryLock.lock()
        defer { registryLock.unlock() }
        recordings[key, default: []].append(request)
    }

    private static func recordedRequests(forKey key: String) -> [RecordedRequest] {
        registryLock.lock()
        defer { registryLock.unlock() }
        return recordings[key] ?? []
    }

    // MARK: - Body extraction

    /// `URLRequest.httpBody` is NOT always populated by the time a `URLProtocol` sees the
    /// request — `URLSession` frequently re-presents the body as `httpBodyStream`. Reading
    /// only `httpBody` yields a silent `nil` and every body assertion passes vacuously.
    ///
    /// **Measured on this tree (`2026-08-15`, macOS, `swift test`): the stream is the LIVE
    /// path.** With the stream branch disabled, `APIClient`'s POST body records as `nil`
    /// while `Content-Length: 366` is still present on the request. The `httpBody` branch
    /// below is the defensive half, not the working one — do not "simplify" the stream drain
    /// away.
    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody, !body.isEmpty { return body }

        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            guard read > 0 else { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }

    // MARK: - URLProtocol

    /// Always `true`: the stub is only ever installed on a dedicated ephemeral session, so
    /// anything reaching it is meant for it. A request without a session key is failed in
    /// `startLoading()` rather than declined here, so the misbinding surfaces as a test
    /// failure instead of an unnoticed live network call.
    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let recorded = RecordedRequest(
            method: request.httpMethod ?? "GET",
            url: request.url,
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.bodyData(from: request)
        )

        guard let key = recorded.header(Self.sessionHeaderName) else {
            client?.urlProtocol(self, didFailWithError: StubError.unkeyedRequest)
            return
        }

        Self.record(recorded, forKey: key)

        guard let outcome = Self.dequeueOutcome(forKey: key) else {
            let error = StubError.noScriptedOutcome(
                method: recorded.method,
                url: recorded.url?.absoluteString ?? "<no url>"
            )
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        switch outcome {
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)

        case .response(let stub):
            guard
                let url = request.url,
                let httpResponse = HTTPURLResponse(
                    url: url,
                    statusCode: stub.statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: stub.headers
                )
            else {
                client?.urlProtocol(
                    self,
                    didFailWithError: StubError.unconstructableResponse(statusCode: stub.statusCode)
                )
                return
            }

            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stub.data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
