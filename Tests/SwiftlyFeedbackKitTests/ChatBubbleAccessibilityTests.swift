import SwiftUI
import Testing
@testable import SwiftlyFeedbackKit

/// What one chat bubble says to assistive tech, and how its sender line breaks.
///
/// A bubble is one accessibility element. It reads in the order a sighted reader takes it in:
/// who wrote it, what they wrote, then when. The sender is often an email address, and an
/// address must never break with a hyphen inside its domain ("north- / wind.app"): it fits on
/// one line, or it breaks after the `@`.
@MainActor
@Suite("Chat bubble accessibility")
struct ChatBubbleAccessibilityTests {

    @Test("VoiceOver reads sender, message, then time")
    func readingOrder() {
        let row = ChatBubbleRow(
            text: "Dark mode would be huge for us.",
            senderName: "sam.okafor@northwind.app",
            avatarName: "sam",
            isOutgoing: false,
            timeText: "yesterday"
        )
        #expect(row.accessibilityText == "sam.okafor@northwind.app, Dark mode would be huge for us., yesterday")
    }

    @Test("A bubble without a time reads sender, then message")
    func readingOrderWithoutTime() {
        let row = ChatBubbleRow(text: "Thanks!", senderName: "Admin", avatarName: "admin", isOutgoing: true)
        #expect(row.accessibilityText == "Admin, Thanks!")
    }

    @Test("An email sender breaks only after the @")
    func emailBreaksAfterAt() {
        #expect(ChatBubbleRow<EmptyView>.senderNameLines("sam.okafor@northwind.app") == ["sam.okafor@", "northwind.app"])
        #expect(ChatBubbleRow<EmptyView>.senderNameLines("priya.raman@northwind.app") == ["priya.raman@", "northwind.app"])
    }

    @Test("The drawn sender offers one break, after the @, and reads as the plain address")
    func displayedAddressBreaksAfterAt() {
        #expect(ChatBubbleRow<EmptyView>.senderNameDisplay("sam.okafor@northwind.app") == "sam.okafor@\u{200B}northwind.app")
        #expect(ChatBubbleRow<EmptyView>.senderNameDisplay("Admin") == "Admin")
    }

    @Test("A sender that is not an address stays one line")
    func plainNameIsOneLine() {
        #expect(ChatBubbleRow<EmptyView>.senderNameLines("Admin") == ["Admin"])
        #expect(ChatBubbleRow<EmptyView>.senderNameLines("Jordan Lee") == ["Jordan Lee"])
    }

    @Test("A leading or trailing @ is not a break point")
    func degenerateAt() {
        #expect(ChatBubbleRow<EmptyView>.senderNameLines("@handle") == ["@handle"])
        #expect(ChatBubbleRow<EmptyView>.senderNameLines("handle@") == ["handle@"])
    }

    @Test("The domain breaks at the last @, so a quoted local part stays whole")
    func lastAt() {
        #expect(ChatBubbleRow<EmptyView>.senderNameLines("\"a@b\"@example.com") == ["\"a@b\"@", "example.com"])
    }
}
