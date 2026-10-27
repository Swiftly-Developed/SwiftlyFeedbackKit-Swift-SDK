#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import SwiftUI
import Testing
@testable import SwiftlyFeedbackKit

/// The Classic vote column's count sits centered under the chevron on macOS.
///
/// The count is a `SystemLabel`. Its AppKit label reported no fitted size, so it took the whole
/// 44-point column and drew its text from the leading edge: "128" ran out of the box on the
/// left while the chevron stayed centered.
@Suite("Vote button count layout")
@MainActor
struct VoteButtonCountLayoutTests {
    private static func countField(in button: VoteButton, text: String) throws -> (field: NSTextField, host: NSView) {
        let host = NSHostingView(rootView: button)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let field = try #require(Self.textFields(in: host).first { $0.stringValue == text })
        return (field, host)
    }

    private static func textFields(in view: NSView) -> [NSTextField] {
        view.subviews.flatMap { subview in
            (subview as? NSTextField).map { [$0] } ?? textFields(in: subview)
        }
    }

    /// Rows in a window's list, laid out once, as a board first appears.
    @Test("In a list, every row's count is centered on its first layout")
    func countIsCenteredInAList() throws {
        let counts = [128, 86, 64, 41, 9]
        let list = List(counts, id: \.self) { count in
            HStack {
                VoteButton(voteCount: count, hasVoted: count != 64, status: .approved, action: {})
                Text("Request \(count)")
            }
        }
        .listStyle(.plain)
        let host = NSHostingView(rootView: list)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        window.contentView = host
        window.layoutIfNeeded()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        host.layoutSubtreeIfNeeded()

        let fields = Self.textFields(in: host)
        for count in counts {
            let text = count.formatted(.number)
            let field = try #require(fields.first { $0.stringValue == text }, "No count field for \(text)")
            let textWidth = try #require(field.cell).cellSize(
                forBounds: NSRect(x: 0, y: 0, width: 1_000, height: 1_000)
            ).width
            // A field as wide as its text is centered by the column's stack; one as wide as
            // the column draws its text from the leading edge. SwiftUI places the field by its
            // alignment rect, which leaves out AppKit's label insets.
            let placed = field.alignmentRect(forFrame: field.frame)
            #expect(placed.width < 44, "\(text) takes the whole column: \(placed)")
            #expect(abs(placed.width - ceil(textWidth)) <= 1, "\(text) is not sized to its text: \(placed)")
        }
    }

    @Test("The count is as wide as its text and centered in the column", arguments: [
        (128, true), (86, true), (63, false), (9, false), (1_284, true),
    ])
    func countIsCentered(count: Int, hasVoted: Bool) throws {
        let text = count.formatted(.number)
        let (field, host) = try Self.countField(
            in: VoteButton(voteCount: count, hasVoted: hasVoted, status: .approved, action: {}),
            text: text
        )
        let frame = field.convert(field.bounds, to: host)

        #expect(frame.width < host.bounds.width, "The count takes the whole column, so its text starts at the leading edge")
        #expect(abs(frame.midX - host.bounds.midX) <= 1, "The count is off center: \(frame) in \(host.bounds)")
        #expect(frame.minX >= host.bounds.minX, "The count runs out of the column")
    }
}
#endif
