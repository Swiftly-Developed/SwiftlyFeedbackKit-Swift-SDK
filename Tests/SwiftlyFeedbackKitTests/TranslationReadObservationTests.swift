import Foundation
import Observation
import os
import Testing
@testable import SwiftlyFeedbackKit

/// The feedback list calls `FeedbackTranslator.translation(for:)` from its `body`.
/// That read must not publish an Observation change: a publish invalidates the view,
/// which reads again, and the main thread never leaves the SwiftUI update loop.
@Suite @MainActor struct TranslationReadObservationTests {

    private func makeUnit() -> TranslatableUnit {
        TranslatableUnit(
            itemID: UUID(),
            field: .title,
            sourceText: "Bitte fügt einen Dunkelmodus hinzu",
            sourceLanguage: Locale.Language(identifier: "de")
        )
    }

    @Test("A cache-hit read on the view path does not publish an Observation change")
    func cacheHitReadDoesNotPublish() {
        let translator = FeedbackTranslator()
        let unit = makeUnit()
        let target = Locale.Language(identifier: "en")
        translator.preloadCachedTranslation(unit, target: target, translatedText: "Please add a dark mode")

        let publications = OSAllocatedUnfairLock(initialState: 0)
        withObservationTracking {
            _ = translator.translation(
                for: unit.itemID,
                field: unit.field,
                target: target,
                sourceText: unit.sourceText
            )
        } onChange: {
            publications.withLock { $0 += 1 }
        }

        _ = translator.translation(
            for: unit.itemID,
            field: unit.field,
            target: target,
            sourceText: unit.sourceText
        )

        #expect(publications.withLock { $0 } == 0)
    }

    @Test("A cache-miss read on the view path does not publish an Observation change")
    func cacheMissReadDoesNotPublish() {
        let translator = FeedbackTranslator()
        let unit = makeUnit()
        let target = Locale.Language(identifier: "en")

        let publications = OSAllocatedUnfairLock(initialState: 0)
        withObservationTracking {
            _ = translator.translation(
                for: unit.itemID,
                field: unit.field,
                target: target,
                sourceText: unit.sourceText
            )
        } onChange: {
            publications.withLock { $0 += 1 }
        }

        _ = translator.translation(
            for: unit.itemID,
            field: unit.field,
            target: target,
            sourceText: unit.sourceText
        )

        #expect(publications.withLock { $0 } == 0)
    }
}
