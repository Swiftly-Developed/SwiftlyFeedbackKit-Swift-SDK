import Testing
@testable import SwiftlyFeedbackKit

/// What `FeedbackListView` wraps itself in on iOS and visionOS.
///
/// A host that owns navigation passes `embedsNavigationStack: false`. The list used to drop
/// its own stack only at compact width; at regular width it still built a split view, which
/// inside the host's split and stack hid the list behind a second Show Sidebar button
/// (the Admin app's Feature Requests on iPad).
@Suite("Feedback list container")
struct FeedbackListContainerTests {

    @Test("Standalone, compact width is one stack and regular width a split")
    func standalone() {
        #expect(FeedbackListView.container(embedsNavigationStack: true, isCompact: true) == .stack)
        #expect(FeedbackListView.container(embedsNavigationStack: true, isCompact: false) == .split)
    }

    @Test("Inside a host's navigation, the list adds no container at any width")
    func hosted() {
        #expect(FeedbackListView.container(embedsNavigationStack: false, isCompact: true) == .none)
        #expect(FeedbackListView.container(embedsNavigationStack: false, isCompact: false) == .none)
    }
}
