import Testing
@testable import SwiftlyFeedbackKit

/// `FEEDBACK01` §18 — the list-style option and the category-filter switch.
@Suite("Feedback list configuration", .serialized)
@MainActor
struct FeedbackListConfigurationTests {

    @Test("A fresh configuration defaults to the Showcase list style")
    func defaultsToShowcase() {
        #expect(SwiftlyFeedbackConfiguration().listStyle == .showcase)
    }

    @Test("Classic is selectable and round-trips")
    func classicIsSelectable() {
        let saved = SwiftlyFeedback.configuration.listStyle
        defer { SwiftlyFeedback.configuration.listStyle = saved }

        SwiftlyFeedback.configuration.listStyle = .classic
        #expect(SwiftlyFeedback.configuration.listStyle == .classic)
        SwiftlyFeedback.configuration.listStyle = .showcase
        #expect(SwiftlyFeedback.configuration.listStyle == .showcase)
    }

    @Test("The list style has exactly two cases")
    func twoStyles() {
        #expect(FeedbackListStyle.allCases == [.showcase, .classic])
    }

    @Test("The category filter shows by default and mirrors the status filter switch")
    func categoryFilterDefaultsOn() {
        let fresh = SwiftlyFeedbackConfiguration()
        #expect(fresh.buttons.categoryFilter.display)
        #expect(fresh.buttons.statusFilter.display)

        fresh.buttons.categoryFilter.display = false
        #expect(fresh.buttons.categoryFilter.display == false)
        #expect(fresh.buttons.statusFilter.display)
    }
}
