import Foundation

/// Four-state load model for the feedback list.
///
/// The SDK's equivalent of the Admin app's `LoadingState` shape (the SDK cannot
/// import Admin code). Same deliberate deviation from `STATE-MANAGEMENT.md` §4:
/// `any Error` is neither `Sendable` nor `Equatable`, so the already-localized
/// *message* rides the enum rather than the error itself.
///
/// Empty state is thereby gated on a fetch-completed fact (`.loaded([])`),
/// never on a bare `array.isEmpty` — see UI-DESIGN-IOS.md → "Loading, Empty, Error".
enum FeedbackLoadState: Equatable {
    /// No request has been made yet (or the last one was cancelled with nothing loaded).
    case idle
    /// The initial content load is in flight. Populated refreshes stay `.loaded`.
    case loading
    /// The load completed; the associated value is the fetched collection (possibly empty).
    case loaded([Feedback])
    /// The initial content load failed; the message is already localized for display.
    case failed(message: String)
}
