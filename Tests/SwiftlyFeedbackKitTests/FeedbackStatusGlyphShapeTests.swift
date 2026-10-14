import Testing
@testable import SwiftlyFeedbackKit

/// `FEEDBACK01` §6.3 — the status eyebrow encodes status by shape as well as colour.
///
/// Sits beside `FeedbackStatusPresentationGapTests`, which pins that the public `FeedbackStatus`
/// has no glyph member. This mapping is internal on purpose.
@Suite("Feedback status glyph shape")
struct FeedbackStatusGlyphShapeTests {

    static let expected: [(status: FeedbackStatus, shape: FeedbackStatusGlyphShape)] = [
        (.pending, .dashedRing),
        (.approved, .ring),
        (.inProgress, .halfRing),
        (.testflight, .threeQuarterRing),
        (.completed, .check),
        (.rejected, .cross),
    ]

    @Test("Each status maps to its own shape", arguments: FeedbackStatusGlyphShapeTests.expected)
    func shapePerStatus(_ row: (status: FeedbackStatus, shape: FeedbackStatusGlyphShape)) {
        #expect(FeedbackStatusGlyphShape(status: row.status) == row.shape)
    }

    @Test("Six statuses map to six distinct shapes and six distinct menu symbols")
    func shapesAreDistinct() {
        #expect(FeedbackStatus.allCases.count == 6)
        let shapes = FeedbackStatus.allCases.map(FeedbackStatusGlyphShape.init(status:))
        #expect(Set(shapes).count == 6)
        let symbols = shapes.map(\.menuSymbolName)
        #expect(Set(symbols).count == 6)
        #expect(symbols.allSatisfy { !$0.isEmpty })
    }

    @Test("Only the closed statuses get a filled mark")
    func filledMarksAreTheClosedStatuses() {
        for status in FeedbackStatus.allCases {
            #expect(FeedbackStatusGlyphShape(status: status).isFilledMark == !status.canVote)
        }
    }
}
