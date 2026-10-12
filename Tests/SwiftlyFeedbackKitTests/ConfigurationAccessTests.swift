import Foundation
import SwiftUI
import Testing
@testable import SwiftlyFeedbackKit

/// The main-actor configuration API and the deprecated `config` / `theme` / `shared` shims.
///
/// The shims exist so a 1.x call site still compiles. These cases are that call site: they
/// write through the old names and read through the new ones, and the other way around.
@Suite("Configuration access", .serialized)
@MainActor
struct ConfigurationAccessTests {

    @Test("configuration round-trips on the main actor")
    func configurationRoundTrips() {
        let saved = SwiftlyFeedback.configuration.allowUndoVote
        defer { SwiftlyFeedback.configuration.allowUndoVote = saved }

        SwiftlyFeedback.configuration.allowUndoVote = false
        #expect(SwiftlyFeedback.configuration.allowUndoVote == false)
        SwiftlyFeedback.configuration.allowUndoVote = true
        #expect(SwiftlyFeedback.configuration.allowUndoVote == true)
    }

    @Test("deprecated config forwards to configuration")
    func deprecatedConfigForwards() {
        let saved = SwiftlyFeedback.configuration
        let savedUndo = saved.allowUndoVote
        let savedVotes = saved.showVoteCount
        defer {
            SwiftlyFeedback.configuration = saved
            saved.allowUndoVote = savedUndo
            saved.showVoteCount = savedVotes
        }

        SwiftlyFeedback.config.allowUndoVote = false
        #expect(SwiftlyFeedback.configuration.allowUndoVote == false)
        #expect(SwiftlyFeedback.config === SwiftlyFeedback.configuration)

        SwiftlyFeedback.configuration.showVoteCount = false
        #expect(SwiftlyFeedback.config.showVoteCount == false)

        let replacement = SwiftlyFeedbackConfiguration()
        replacement.loggingEnabled = false
        SwiftlyFeedback.config = replacement
        #expect(SwiftlyFeedback.configuration === replacement)
        #expect(SDKLogGate.isEnabled == false)
    }

    @Test("deprecated theme forwards to appearance")
    func deprecatedThemeForwards() {
        let saved = SwiftlyFeedback.appearance.primaryColor
        defer { SwiftlyFeedback.appearance.primaryColor = saved }

        SwiftlyFeedback.theme.primaryColor = .color(.mint)
        #expect(SwiftlyFeedback.appearance.primaryColor == .color(.mint))
        #expect(SwiftlyFeedback.theme === SwiftlyFeedback.appearance)

        SwiftlyFeedback.appearance.primaryColor = .default
        #expect(SwiftlyFeedback.theme.primaryColor == .default)
    }

    @Test("deprecated shared forwards to current")
    func deprecatedSharedForwards() {
        let saved = SwiftlyFeedback.current
        defer { SwiftlyFeedback.current = saved }

        let client = SwiftlyFeedback(
            apiKey: "test_key",
            userId: "user",
            baseURL: URL(string: "https://example.com/api/v1")!
        )
        SwiftlyFeedback.shared = client
        #expect(SwiftlyFeedback.current === client)

        SwiftlyFeedback.current = nil
        #expect(SwiftlyFeedback.shared == nil)
    }

    @Test("logging gate follows loggingEnabled")
    func loggingGateFollowsTheFlag() {
        let saved = SwiftlyFeedback.configuration.loggingEnabled
        defer {
            SwiftlyFeedback.configuration.loggingEnabled = saved
            #expect(SDKLogGate.isEnabled == saved)
        }

        SwiftlyFeedback.configuration.loggingEnabled = false
        #expect(SDKLogGate.isEnabled == false)
        SwiftlyFeedback.config.loggingEnabled = true
        #expect(SDKLogGate.isEnabled == true)
    }
}
