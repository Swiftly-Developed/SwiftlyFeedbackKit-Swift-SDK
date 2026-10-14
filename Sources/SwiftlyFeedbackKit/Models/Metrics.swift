//  Metrics.swift
//  SwiftlyFeedbackKit
//
//  The X-API-Key metrics surface's response models and closed vocabularies.
//
//  Every shape here mirrors METRICS03 phase 01 §6 — C3 (the nine meta fields), C4 (the
//  per-operation response shapes and the sparsity rule), C5 (the closed vocabularies) and
//  C7 (the 17 error tokens). The server owns the contract; nothing in this file re-derives
//  it, pre-rejects a request, or fills in a value the server omitted.
//
//  Two decoding facts this file depends on, both measured rather than assumed:
//
//    * `APIClient`'s decoder runs `.convertFromSnakeCase`, and `Dictionary`'s own
//      `Decodable` conformance is EXEMPT from the key strategy. A bare `[String: Double]`
//      therefore binds the server's snake_case measure tokens verbatim. A hand-written
//      `init(from:)` that enumerates `container.allKeys` would re-introduce the mangling,
//      because `allKeys` ARE strategy-converted — so neither `values` nor an event's
//      `properties` may grow a custom decoder.
//    * `values` is SPARSE by design. A breakdown's overflow row omits `unique_event_users`
//      entirely, because a distinct-user count is not additive across elided names. Every
//      typed measure accessor below therefore returns `Double?`.

import Foundation

// MARK: - Closed vocabularies (C5)

/// A measure the metrics API can report.
///
/// Nine members. Five are readable on the `X-API-Key` surface the SDK speaks; the other
/// four are Bearer-only and are answered there with a typed 403.
public enum MetricMeasure: String, Codable, Sendable, CaseIterable, Hashable {
    case feedbackCount = "feedback_count"
    case voteCount = "vote_count"
    case commentCount = "comment_count"
    case eventCount = "event_count"
    case uniqueEventUsers = "unique_event_users"
    case sdkUserCount = "sdk_user_count"
    case mrrSum = "mrr_sum"
    case mrrAverage = "mrr_average"
    case usersWithMrr = "users_with_mrr"

    /// Whether this measure is readable on the `X-API-Key` surface.
    ///
    /// ⚠️ **An ergonomic affordance, not a boundary.** The server owns the allow-list. The
    /// SDK deliberately does *not* consult this property before sending a request: asking
    /// for a Bearer-only measure issues the request and surfaces
    /// ``SwiftlyFeedbackError/measureNotAvailable(measure:message:)``, which is the
    /// behaviour the contract specifies. Reading this value as enforcement would duplicate
    /// a server rule the client cannot keep in step.
    public var isAvailableOnAPIKey: Bool {
        switch self {
        case .feedbackCount, .voteCount, .commentCount, .eventCount, .uniqueEventUsers:
            return true
        case .sdkUserCount, .mrrSum, .mrrAverage, .usersWithMrr:
            return false
        }
    }
}

/// The bucket width of a timeseries.
///
/// ⚠️ The raw values are the **wire tokens**. The server's own Swift case names are
/// `hourly`/`daily`/…; those never appear on the wire and must not be sent.
public enum MetricGranularity: String, Codable, Sendable, CaseIterable, Hashable {
    case hour
    case day
    case week
    case month
}

/// The axis a breakdown groups by.
public enum MetricDimension: String, Codable, Sendable, CaseIterable, Hashable {
    case status
    case category
    case eventName = "event_name"
}

/// Which events a response counted.
///
/// A `predefinedOnly` response is a **success**, not an error: below Pro the customer's own
/// event names are ingested and retained but not readable, so the server answers the
/// narrower question and says so here.
public enum MetricEventScope: String, Codable, Sendable, CaseIterable, Hashable {
    case all
    case predefinedOnly = "predefined_only"
}

/// The three event names FeedbackKit reserves and tracks itself.
///
/// These are **re-expressed** from ``PredefinedView``, which already carries exactly these
/// raw values — the two are bridged below by exhaustive switches, so a member added to
/// either side is a compile error rather than a silent divergence. Matching is exact and
/// case-sensitive: an event name differing only in case is a *custom* event and lands on
/// the paid side of the tier gate.
public enum PredefinedEventName: String, Codable, Sendable, CaseIterable, Hashable {
    case feedbackList = "feedback_list"
    case feedbackDetail = "feedback_detail"
    case submitFeedback = "submit_feedback"

    /// The tracking-side spelling of the same event.
    public var predefinedView: PredefinedView {
        switch self {
        case .feedbackList: return .feedbackList
        case .feedbackDetail: return .feedbackDetail
        case .submitFeedback: return .submitFeedback
        }
    }

    /// The metrics-side spelling of a tracked predefined view.
    public init(_ view: PredefinedView) {
        switch view {
        case .feedbackList: self = .feedbackList
        case .feedbackDetail: self = .feedbackDetail
        case .submitFeedback: self = .submitFeedback
        }
    }
}

// MARK: - Error vocabulary (C7)

/// The 17 machine-readable tokens the metrics API's enveloped error body carries at
/// `error.code`.
///
/// 19 server-side cases collapse to these 17: the three custom-event refusals share
/// `METRICS_CUSTOM_EVENTS_REQUIRE_PRO` and keep distinct server-side tokens for logs.
///
/// Recognition is **non-failable** everywhere it is used — an eighteenth token added by a
/// future server release reads as `nil` here and leaves the untyped message intact, rather
/// than turning the whole error body into a decode failure.
public enum MetricsErrorCode: String, Codable, Sendable, CaseIterable, Hashable {
    case bucketLimitExceeded = "METRICS_BUCKET_LIMIT_EXCEEDED"
    case conflictingWindowParams = "METRICS_CONFLICTING_WINDOW_PARAMS"
    case customEventsRequirePro = "METRICS_CUSTOM_EVENTS_REQUIRE_PRO"
    case filterNotAvailableForEndpoint = "METRICS_FILTER_NOT_AVAILABLE_FOR_ENDPOINT"
    case invalidCategory = "METRICS_INVALID_CATEGORY"
    case invalidDate = "METRICS_INVALID_DATE"
    case invalidDateRange = "METRICS_INVALID_DATE_RANGE"
    case invalidEventName = "METRICS_INVALID_EVENT_NAME"
    case invalidPage = "METRICS_INVALID_PAGE"
    case invalidPerPage = "METRICS_INVALID_PER_PAGE"
    case invalidStatus = "METRICS_INVALID_STATUS"
    case measureNotAvailableForEndpoint = "METRICS_MEASURE_NOT_AVAILABLE_FOR_ENDPOINT"
    case measureRequiresBearer = "METRICS_MEASURE_REQUIRES_BEARER"
    case measuresRequired = "METRICS_MEASURES_REQUIRED"
    case unknownDimension = "METRICS_UNKNOWN_DIMENSION"
    case unknownGranularity = "METRICS_UNKNOWN_GRANULARITY"
    case unknownMeasure = "METRICS_UNKNOWN_MEASURE"
}

// MARK: - Responses (C3, C4)

/// The `meta` block every metrics response carries. Nine fields, of which `granularity` is
/// the only optional one.
///
/// `granularity` is **absent** — never `null` — on `summary` and on the event feed's
/// `metrics` block, and **present** on `timeseries` *and* on `breakdown` (where the server
/// echoes `"day"` by default and does not use it to bucket anything). A model declaring it
/// non-optional fails to decode two of the four operations.
public struct MetricsMeta: Codable, Sendable, Equatable, Hashable {
    /// The resolved measure list, in first-seen order, as the server's wire tokens.
    public let measures: [String]
    /// The resolved bucket width. Absent on `summary` and on the event feed.
    public let granularity: MetricGranularity?
    /// The reporting time zone actually applied.
    public let timezone: String
    /// The inclusive first instant of the window.
    public let dateFrom: Date
    /// The inclusive last instant of the window — never the exclusive end.
    public let dateTo: Date
    /// True only when a breakdown's cardinality ceiling elided names.
    public let truncated: Bool
    /// Which events were counted.
    public let eventScope: MetricEventScope
    /// True when the plan narrowed the requested window.
    ///
    /// ⚠️ Not idempotent by design: re-requesting an already-clamped window returns the
    /// same window with this flag `false`. Never derive it by comparing the request to the
    /// response.
    public let retentionClamped: Bool
    /// The plan's window allowance, in days (Free 30, Pro 90, Team 365).
    /// Never hardcode 30, 90, or 365 — read this.
    public let retentionWindowDays: Int

    public init(
        measures: [String],
        granularity: MetricGranularity?,
        timezone: String,
        dateFrom: Date,
        dateTo: Date,
        truncated: Bool,
        eventScope: MetricEventScope,
        retentionClamped: Bool,
        retentionWindowDays: Int
    ) {
        self.measures = measures
        self.granularity = granularity
        self.timezone = timezone
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.truncated = truncated
        self.eventScope = eventScope
        self.retentionClamped = retentionClamped
        self.retentionWindowDays = retentionWindowDays
    }

    /// The measures the server resolved, as typed members. Tokens this SDK build does not
    /// recognise are dropped rather than failing the decode; `measures` keeps them all.
    public var resolvedMeasures: [MetricMeasure] {
        measures.compactMap(MetricMeasure.init(rawValue:))
    }
}

/// `GET /metrics/summary` — one aggregate row over the whole window.
public struct MetricSummary: Codable, Sendable, Equatable, Hashable {
    public let meta: MetricsMeta
    /// Measure token → value. Keyed by the server's snake_case tokens, verbatim.
    public let values: [String: Double]

    public init(meta: MetricsMeta, values: [String: Double]) {
        self.meta = meta
        self.values = values
    }
}

/// One bucket of a timeseries.
///
/// Exactly two fields. 🔴 There is no bucket-start instant on this type — the bucket key is
/// the only temporal field, and it is parsed rather than displayed raw.
public struct MetricSeriesPoint: Codable, Sendable, Equatable, Hashable {
    /// The bucket key, in the granularity's own spelling (`2023-11-12` at day width).
    public let bucket: String
    /// Measure token → value.
    public let values: [String: Double]

    public init(bucket: String, values: [String: Double]) {
        self.bucket = bucket
        self.values = values
    }
}

/// `GET /metrics/timeseries` — one row per bucket.
///
/// Empty buckets are **present and zero-valued**, not omitted; `series.isEmpty` is not the
/// "no activity" branch.
public struct MetricSeries: Codable, Sendable, Equatable, Hashable {
    public let meta: MetricsMeta
    public let series: [MetricSeriesPoint]

    public init(meta: MetricsMeta, series: [MetricSeriesPoint]) {
        self.meta = meta
        self.series = series
    }
}

/// One group of a breakdown.
public struct MetricBreakdownItem: Codable, Sendable, Equatable, Hashable {
    /// The dimension value this row groups, or the overflow sentinel.
    public let key: String
    /// Measure token → value. **Sparse on the overflow row.**
    public let values: [String: Double]
    /// True on the single synthetic row standing in for the elided names.
    public let isOverflow: Bool

    public init(key: String, values: [String: Double], isOverflow: Bool) {
        self.key = key
        self.values = values
        self.isOverflow = isOverflow
    }
}

/// `GET /metrics/breakdown` — one row per dimension value, ordered by the first measure
/// descending, with at most one trailing overflow row.
public struct MetricBreakdown: Codable, Sendable, Equatable, Hashable {
    public let meta: MetricsMeta
    public let dimension: MetricDimension
    public let items: [MetricBreakdownItem]

    public init(meta: MetricsMeta, dimension: MetricDimension, items: [MetricBreakdownItem]) {
        self.meta = meta
        self.dimension = dimension
        self.items = items
    }
}

/// `GET /metrics/events` — one page of the raw event feed.
///
/// 🔴 **Two meta blocks.** `meta` is the pagination block; the metrics window lives under
/// `metrics`. A model that puts the metrics block under `meta` on this operation decodes
/// nothing.
public struct MetricEventList: Codable, Sendable, Equatable, Hashable {
    /// The page's pagination block.
    public struct Pagination: Codable, Sendable, Equatable, Hashable {
        public let total: Int
        public let page: Int
        public let perPage: Int
        public let totalPages: Int

        public init(total: Int, page: Int, perPage: Int, totalPages: Int) {
            self.total = total
            self.page = page
            self.perPage = perPage
            self.totalPages = totalPages
        }
    }

    public let items: [ViewEventResponse]
    public let meta: Pagination
    public let metrics: MetricsMeta

    public init(items: [ViewEventResponse], meta: Pagination, metrics: MetricsMeta) {
        self.items = items
        self.meta = meta
        self.metrics = metrics
    }
}

// MARK: - Typed measure access (C4)

// Each accessor returns `Double?`. `values` is sparse — a breakdown's overflow row omits
// `unique_event_users` — so a non-optional accessor would crash on a row that is reachable
// in production, not merely in theory.

public extension MetricSummary {
    /// The value for `measure`, or `nil` when the server did not report it.
    subscript(measure: MetricMeasure) -> Double? { values[measure.rawValue] }
}

public extension MetricSeriesPoint {
    /// The value for `measure`, or `nil` when the server did not report it.
    subscript(measure: MetricMeasure) -> Double? { values[measure.rawValue] }
}

public extension MetricBreakdownItem {
    /// The value for `measure`, or `nil` when the server did not report it.
    ///
    /// Returns `nil` on the overflow row for `uniqueEventUsers`, always.
    subscript(measure: MetricMeasure) -> Double? { values[measure.rawValue] }
}
