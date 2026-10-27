import SwiftUI
import Testing
@testable import SwiftlyFeedbackKit

/// Which chat bubbles carry their sender's name.
///
/// The first bubble of a run from one sender is named. In the Admin app the trailing
/// (outgoing) side is the reader's own staff side, so it stays unnamed. In the SDK the
/// trailing side is staff talking to the reader, and an end user could only tell those
/// replies apart by side and colour; there the run is named "Admin" like any other.
@Suite("Chat bubble sender name")
struct ChatBubbleSenderNameTests {

    @Test("An incoming run is named on its first bubble only")
    func incomingRun() {
        #expect(ChatBubbleRow<EmptyView>.showsSenderName(isOutgoing: false, startsGroup: true, showsOutgoingSenderName: false))
        #expect(!ChatBubbleRow<EmptyView>.showsSenderName(isOutgoing: false, startsGroup: false, showsOutgoingSenderName: false))
    }

    @Test("An outgoing run stays unnamed by default, as in the Admin app")
    func outgoingRunByDefault() {
        #expect(!ChatBubbleRow<EmptyView>.showsSenderName(isOutgoing: true, startsGroup: true, showsOutgoingSenderName: false))
    }

    @Test("An outgoing run is named on its first bubble when the host asks, as the SDK does for staff")
    func outgoingRunNamed() {
        #expect(ChatBubbleRow<EmptyView>.showsSenderName(isOutgoing: true, startsGroup: true, showsOutgoingSenderName: true))
        #expect(!ChatBubbleRow<EmptyView>.showsSenderName(isOutgoing: true, startsGroup: false, showsOutgoingSenderName: true))
    }
}
