import Foundation

/// A group of units sharing one source language and one target — the framework expects one
/// source language per session, so a mixed-language list runs as N sequential batches.
/// Pure value logic, all-platform, unit-testable.
struct TranslationBatch: Sendable {
    let source: Locale.Language
    let target: Locale.Language
    let units: [TranslatableUnit]

    /// Groups `units` by detected source language into deterministic batches.
    ///
    /// Units whose source already equals `target` are dropped (translation is not
    /// applicable, the original text stands). The remaining units are grouped by source
    /// and the batches ordered by `source.minimalIdentifier` so the queue is deterministic
    /// regardless of dictionary iteration order.
    static func batches(from units: [TranslatableUnit], target: Locale.Language) -> [TranslationBatch] {
        let applicable = units.filter { $0.sourceLanguage != target }
        let grouped = Dictionary(grouping: applicable, by: \.sourceLanguage)
        return grouped
            .sorted { $0.key.minimalIdentifier < $1.key.minimalIdentifier }
            .map { TranslationBatch(source: $0.key, target: target, units: $0.value) }
    }
}
