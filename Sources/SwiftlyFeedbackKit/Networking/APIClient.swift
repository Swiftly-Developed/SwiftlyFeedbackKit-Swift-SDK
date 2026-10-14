import Foundation

public actor APIClient {
    /// How long one request may wait before it fails as a timeout.
    ///
    /// The other FeedbackKit SDKs use 30 seconds. `URLSession.shared`'s default is 60, and
    /// this is set on the request so the shared session's timeout is left alone.
    static let requestTimeout: TimeInterval = 30

    private let baseURL: URL
    private let apiKey: String
    private var userId: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL, apiKey: String, userId: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.userId = userId
        self.session = session
        self.decoder = WireCoding.makeDecoder()
        self.encoder = WireCoding.makeEncoder()

        SDKLogger.debug("APIClient initialized")
    }

    /// Replaces the id stamped on later requests. Runs on this actor, so it cannot overlap
    /// a request that is already reading `userId` for its header and body.
    func updateUserId(_ userId: String) {
        self.userId = userId
    }

    /// Builds the request URL, keeping the path and the query in their own encodings.
    ///
    /// 🔴 The query must NEVER be concatenated into `path` before this call.
    /// `URL.appendingPathComponent` percent-escapes `?` to `%3F`, which turns the whole
    /// thing into one path segment: the request reaches the server as an unknown route and
    /// answers 404, and `url.query` is nil. `url.path` percent-DECODES, so it prints a bare
    /// `?` and the defect is invisible there — read `url.query` (nil when broken), never
    /// `url.path` or a split of `absoluteString` on `"?"`.
    ///
    /// The query string itself is built by ``URLQueryEncoding``, this package's single home
    /// for that rule, including the `+` → `%2B` step Vapor's form parser requires.
    ///
    /// - Note: `static` and `internal` so it can be measured without a live transport;
    ///   `APIClientQueryEncodingTests` drives it directly.
    static func makeURL(baseURL: URL, path: String, queryItems: [URLQueryItem]) throws -> URL {
        let pathURL = baseURL.appendingPathComponent(path)

        guard let encodedQuery = URLQueryEncoding.query(queryItems) else { return pathURL }

        // ⚠️ Deliberately NOT `URLComponents.percentEncodedQuery`. That setter TRAPS —
        // `Fatal error: Attempting to set percentEncodedQuery with invalid characters`,
        // measured on Swift 6.3.3 — and a trap kills the whole process with no catchable
        // error and no failing assertion to read. `URLQueryEncoding` can only ever hand back
        // a valid string, but a transport is the wrong place to depend on that. `pathURL`'s
        // `absoluteString` is already encoded as a path and `encodedQuery` as a query, so
        // joining them and re-parsing is exact, and it fails by returning nil.
        guard let url = URL(string: pathURL.absoluteString + "?" + encodedQuery) else {
            throw SwiftlyFeedbackError.badRequest(
                message: "Could not build a request URL for path \(path)"
            )
        }
        return url
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil
    ) async throws -> (Data, URLResponse) {
        let url = try Self.makeURL(baseURL: baseURL, path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue(userId, forHTTPHeaderField: "X-User-Id")

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        SDKLogger.info("\(method) \(path)")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                SDKLogger.info("Response: \(httpResponse.statusCode) \(path)")
            }

            return (data, response)
        } catch is CancellationError {
            // Re-throw cancellation without logging - this is expected behavior
            throw CancellationError()
        } catch let urlError as URLError where urlError.code == .cancelled {
            // URLSession cancellation - convert to CancellationError for consistent handling
            throw CancellationError()
        } catch {
            // Offline, timeout, and other transport failures. The status map never runs for
            // these, and the SDK does not retry them: a retried POST would submit twice.
            SDKLogger.error("Network error: \(String(describing: type(of: error)))")
            throw SwiftlyFeedbackError.networkError(underlying: error)
        }
    }

    /// A query-less GET.
    ///
    /// ⚠️ Deliberately carries **no** defaulted `queryItems` parameter. Giving it one would make
    /// it a redeclaration of the two-argument overload below rather than a second entry point,
    /// and `MetricsTransportURL`'s `G2b` — which exists to prove the two agree byte for byte —
    /// would compare a function with itself. (The two spellings collided in the `origin/dev`
    /// merge of `2026-08-25` and git resolved them into exactly that duplicate pair.)
    func get<T: Decodable & Sendable>(path: String) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "GET")
        try validateResponse(response, data: data)
        return try decode(data)
    }

    /// A GET carrying a query string, encoded per ``URLQueryEncoding``.
    ///
    /// An empty `queryItems` produces a URL byte-identical to `get(path:)`'s.
    func get<T: Decodable & Sendable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        let (data, response) = try await makeRequest(
            path: path,
            method: "GET",
            queryItems: queryItems
        )
        try validateResponse(response, data: data)
        return try decode(data)
    }

    func post<T: Decodable & Sendable, B: Encodable & Sendable>(path: String, body: B) async throws -> T {
        let (data, response) = try await makeRequest(path: path, method: "POST", body: body)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    /// POST whose body is built from the user id this actor currently holds.
    ///
    /// Building the body here, in the same turn that writes `X-User-Id`, keeps the body
    /// and the header from naming two different people. `CommentUserID` rejects that split
    /// with 400.
    func postUsingUserId<T: Decodable & Sendable, B: Encodable & Sendable>(
        path: String,
        makeBody: @Sendable (String) -> B
    ) async throws -> T {
        try await post(path: path, body: makeBody(userId))
    }

    func delete<B: Encodable & Sendable>(path: String, body: B) async throws -> VoteResult {
        let (data, response) = try await makeRequest(path: path, method: "DELETE", body: body)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    func deleteUsingUserId<B: Encodable & Sendable>(
        path: String,
        makeBody: @Sendable (String) -> B
    ) async throws -> VoteResult {
        try await delete(path: path, body: makeBody(userId))
    }

    private func decode<T: Decodable & Sendable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            if let salvaged: T = Self.salvageFeedbackList(from: data, decoder: decoder) {
                return salvaged
            }
            SDKLogger.error("Decoding failed: \(String(describing: type(of: error)))")
            throw SwiftlyFeedbackError.decodingError(underlying: error)
        }
    }

    /// Decodes a feedback list one row at a time, dropping rows this SDK build cannot read.
    ///
    /// A new status token would otherwise fail `decoder.decode([Feedback].self)` and blank
    /// the whole list. Known rows, including `testflight`, still decode. Returns nil when
    /// `T` is not `[Feedback]` or the payload is not a JSON array, so a single-object
    /// failure stays a decoding error.
    private static func salvageFeedbackList<T>(from data: Data, decoder: JSONDecoder) -> T? {
        guard T.self == [Feedback].self else { return nil }
        guard let rows = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }

        var kept: [Feedback] = []
        for row in rows {
            guard JSONSerialization.isValidJSONObject(row),
                  let rowData = try? JSONSerialization.data(withJSONObject: row),
                  let item = try? decoder.decode(Feedback.self, from: rowData) else {
                continue
            }
            kept.append(item)
        }

        let dropped = rows.count - kept.count
        if dropped > 0 {
            SDKLogger.error("Dropped \(dropped) undecodable feedback row(s)")
        }
        return kept as? T
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            SDKLogger.error("Invalid response type")
            throw SwiftlyFeedbackError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 400:
            let errorMessage = parseErrorMessage(from: data)
            SDKLogger.error("Bad request (400)")
            throw SwiftlyFeedbackError.badRequest(message: errorMessage)
        case 401:
            let errorMessage = parseErrorMessage(from: data)
            if errorMessage?.lowercased().contains("invalid api key") == true {
                SDKLogger.error("Invalid API key (401)")
                throw SwiftlyFeedbackError.invalidApiKey
            }
            SDKLogger.error("Unauthorized (401)")
            throw SwiftlyFeedbackError.unauthorized
        case 402:
            let errorMessage = parseErrorMessage(from: data)
            // The tier refusal is keyed on the ENVELOPE's code, never on the status. Every
            // 402 the feedback / project / member caps raise arrives in the boolean shape
            // with no code at all, and keeps its shipped case.
            if Self.envelopedPayload(from: data)?.metricsCode == .customEventsRequirePro {
                SDKLogger.error("Tier upgrade required (402)")
                throw SwiftlyFeedbackError.tierUpgradeRequired(
                    code: .customEventsRequirePro,
                    message: errorMessage
                )
            }
            SDKLogger.error("Payment required (402)")
            throw SwiftlyFeedbackError.feedbackLimitReached(message: errorMessage)
        case 403:
            // 403 arrives in BOTH body shapes and the two must stay distinguishable: the
            // enveloped measure rejection points the caller at the Bearer endpoint, while
            // the boolean shape is a role, access or suspension refusal.
            let errorMessage = parseErrorMessage(from: data)
            let payload = Self.envelopedPayload(from: data)
            if payload?.metricsCode == .measureRequiresBearer {
                SDKLogger.error("Measure not available on this surface (403)")
                throw SwiftlyFeedbackError.measureNotAvailable(
                    measure: payload?.subjectName,
                    message: errorMessage
                )
            }
            SDKLogger.error("Forbidden (403)")
            throw SwiftlyFeedbackError.forbidden(message: errorMessage)
        case 404:
            SDKLogger.error("Not found (404)")
            throw SwiftlyFeedbackError.notFound
        case 409:
            SDKLogger.error("Conflict (409)")
            throw SwiftlyFeedbackError.conflict
        case 429:
            let errorMessage = parseErrorMessage(from: data)
            SDKLogger.error("Rate limited (429)")
            throw SwiftlyFeedbackError.rateLimited(message: errorMessage)
        default:
            SDKLogger.error("Server error (\(httpResponse.statusCode))")
            throw SwiftlyFeedbackError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        struct ErrorResponse: Decodable {
            let error: Bool?
            let reason: String?
            let message: String?
        }

        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return errorResponse.reason ?? errorResponse.message
        }

        // Third source, appended rather than inserted: the metrics envelope carries neither
        // a top-level `reason` nor a top-level `message`, and it never decodes as the shape
        // above (its `error` is an object, so `Bool?` throws a type mismatch). The
        // reason-beats-message precedence of the two shipped sources is untouched.
        if let payload = Self.envelopedPayload(from: data), let message = payload.message {
            return message
        }

        return String(data: data, encoding: .utf8)
    }

    func validatedData(path: String, queryItems: [URLQueryItem] = []) async throws -> Data {
        let (data, response) = try await makeRequest(path: path, method: "GET", queryItems: queryItems)
        try validateResponse(response, data: data)
        return data
    }

    func collectFeedbackList(
        path: String,
        queryItems: [URLQueryItem],
        page: Int?,
        perPage: Int?
    ) async throws -> [Feedback] {
        try await collectList(Feedback.self, path: path, queryItems: queryItems, page: page, perPage: perPage, tolerantElementDrop: true)
    }

    func collectCommentList(
        path: String,
        queryItems: [URLQueryItem],
        page: Int?,
        perPage: Int?
    ) async throws -> [Comment] {
        try await collectList(Comment.self, path: path, queryItems: queryItems, page: page, perPage: perPage, tolerantElementDrop: false)
    }

    /// Reads one page when `page` is set. When it is omitted, follows `meta`
    /// until the collection is complete. A JSON array is the previous server
    /// and is already the whole collection, so this does not request page 2.
    private func collectList<Item: Decodable>(
        _ type: Item.Type,
        path: String,
        queryItems: [URLQueryItem],
        page: Int?,
        perPage: Int?,
        tolerantElementDrop: Bool
    ) async throws -> [Item] {
        let first = try decodeListPage(
            type,
            from: try await validatedData(path: path, queryItems: queryItems + Self.pageQuery(page: page, perPage: perPage)),
            tolerantElementDrop: tolerantElementDrop
        )
        if first.isLegacyArray || page != nil {
            return first.items
        }
        guard let meta = first.meta, meta.perPage >= 1, !first.items.isEmpty, meta.page < meta.totalPages else {
            return first.items
        }

        var items = first.items
        var next = meta.page + 1
        var size = meta.perPage
        var totalPages = meta.totalPages
        while next <= totalPages && next <= Self.maxFollowedPages {
            let more = try decodeListPage(
                type,
                from: try await validatedData(
                    path: path,
                    queryItems: queryItems + Self.pageQuery(page: next, perPage: size)
                ),
                tolerantElementDrop: tolerantElementDrop
            )
            if more.isLegacyArray {
                break
            }
            items.append(contentsOf: more.items)
            guard let moreMeta = more.meta,
                  moreMeta.perPage >= 1,
                  !more.items.isEmpty,
                  moreMeta.page < moreMeta.totalPages else {
                break
            }
            next = moreMeta.page + 1
            size = moreMeta.perPage
            totalPages = moreMeta.totalPages
        }
        return items
    }

    private static let maxFollowedPages = 100

    private static func pageQuery(page: Int?, perPage: Int?) -> [URLQueryItem] {
        var items: [URLQueryItem] = [URLQueryItem(name: "paged", value: "1")]
        if let page {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if let perPage {
            items.append(URLQueryItem(name: "per_page", value: String(perPage)))
        }
        return items
    }

    private struct DecodedListPage<Item> {
        var items: [Item]
        var meta: ListPageMeta?
        var isLegacyArray: Bool
    }

    private struct ListPageMeta {
        var page: Int
        var perPage: Int
        var totalPages: Int
    }

    private func decodeListPage<Item: Decodable>(
        _ type: Item.Type,
        from data: Data,
        tolerantElementDrop: Bool
    ) throws -> DecodedListPage<Item> {
        let json = try JSONSerialization.jsonObject(with: data)
        if let rows = json as? [Any] {
            return DecodedListPage(
                items: try decodeRows(type, rows: rows, tolerantElementDrop: tolerantElementDrop),
                meta: nil,
                isLegacyArray: true
            )
        }
        guard let object = json as? [String: Any], let rows = object["items"] as? [Any] else {
            throw SwiftlyFeedbackError.decodingError(
                underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Feedback list is neither a page nor an array"))
            )
        }
        let metaObject = object["meta"] as? [String: Any]
        let meta = ListPageMeta(
            page: (metaObject?["page"] as? NSNumber)?.intValue ?? 1,
            perPage: (metaObject?["per_page"] as? NSNumber)?.intValue ?? rows.count,
            totalPages: (metaObject?["total_pages"] as? NSNumber)?.intValue ?? 1
        )
        return DecodedListPage(
            items: try decodeRows(type, rows: rows, tolerantElementDrop: tolerantElementDrop),
            meta: meta,
            isLegacyArray: false
        )
    }

    private func decodeRows<Item: Decodable>(
        _ type: Item.Type,
        rows: [Any],
        tolerantElementDrop: Bool
    ) throws -> [Item] {
        var kept: [Item] = []
        for row in rows {
            guard JSONSerialization.isValidJSONObject(row),
                  let rowData = try? JSONSerialization.data(withJSONObject: row) else {
                if tolerantElementDrop { continue }
                throw SwiftlyFeedbackError.decodingError(
                    underlying: DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "List row is not a JSON object"))
                )
            }
            do {
                kept.append(try decoder.decode(Item.self, from: rowData))
            } catch {
                if tolerantElementDrop { continue }
                throw SwiftlyFeedbackError.decodingError(underlying: error)
            }
        }
        let dropped = rows.count - kept.count
        if dropped > 0 {
            SDKLogger.error("Dropped \(dropped) undecodable list row(s)")
        }
        return kept
    }

    // MARK: - The enveloped error body

    /// The metrics API's error envelope: `error` is an OBJECT carrying a machine-readable
    /// code, alongside a `timestamp`.
    ///
    /// This is the discriminator for the whole two-shape error map. The shared middleware's
    /// body spells `error` as a **boolean**, so it fails to decode here — which is the
    /// signal, not an accident. Branching on the status code alone cannot work: 403 arrives
    /// in both shapes.
    struct EnvelopedError: Decodable {
        struct Payload: Decodable {
            let code: String?
            let message: String?
            let field: String?

            /// The typed code, or `nil` for a token this SDK build does not know. Never a
            /// decode failure — a future eighteenth token must degrade to an untyped error,
            /// not to an unreadable response.
            var metricsCode: MetricsErrorCode? {
                code.flatMap(MetricsErrorCode.init(rawValue:))
            }

            /// The subject the server named, as the server spelled it.
            ///
            /// The measure rejection puts the offending measure in single quotes inside the
            /// prose (`field` names the *parameter*, `measures`), so the quoted token is
            /// preferred and `field` is the fallback. Never re-derived from the request —
            /// the server decides which measure it refused.
            var subjectName: String? {
                if let message,
                   let open = message.firstIndex(of: "'"),
                   let close = message[message.index(after: open)...].firstIndex(of: "'") {
                    let quoted = String(message[message.index(after: open)..<close])
                    if !quoted.isEmpty { return quoted }
                }
                return field
            }
        }

        let error: Payload
        let timestamp: String?
    }

    static func envelopedPayload(from data: Data) -> EnvelopedError.Payload? {
        (try? JSONDecoder().decode(EnvelopedError.self, from: data))?.error
    }
}
