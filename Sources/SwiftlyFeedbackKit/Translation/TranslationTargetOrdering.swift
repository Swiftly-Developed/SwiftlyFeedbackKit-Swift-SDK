import Foundation

/// Puts the device's target languages in the order a reader should meet them.
///
/// Pure and synchronous: same inputs, same output, no environment read anywhere inside.
/// The reader's own languages default to the system list at the call site so a test can
/// hand it a fixture instead — a dev machine is a fixture, and this workstation's system
/// list is a single non-English entry.
enum TranslationTargetOrdering {

    /// `supported` in reading order: the reader's own languages first, then the rest by
    /// localized name under `displayLocale`, with a stable tail-break on the identifier.
    ///
    /// A language with no localized name is **dropped** — a raw code is never rendered,
    /// and absence is the fallback, consistent with the affordance's existing rule. So is
    /// a second entry equivalent to one already kept, for the reason spelled out at the
    /// de-duplication below. The result is therefore always a subset of `supported`, in
    /// particular empty for an empty input, which is what makes the control absent rather
    /// than disabled.
    ///
    /// Two ranks, not one. An exact match — same language, same script, same region —
    /// outranks a same-language match, so a reader on British English meets British
    /// English before plain English, while a reader on Austrian German still meets German
    /// rather than nothing.
    static func ordered(
        supported: [Locale.Language],
        preferred: [Locale] = Locale.preferredLocales,
        displayLocale: Locale
    ) -> [Locale.Language] {
        let readerLanguages = preferred.map(\.language)

        func rank(_ language: Locale.Language) -> Int {
            for (index, reader) in readerLanguages.enumerated() {
                if reader.isEquivalent(to: language) { return index * 2 }
                if reader.isSameLanguage(as: language) { return index * 2 + 1 }
            }
            return Int.max
        }

        let named = supported.compactMap { language -> (language: Locale.Language, name: String)? in
            guard let name = language.localizedTargetName(in: displayLocale) else { return nil }
            return (language, name)
        }

        // Two entries the preference store cannot tell apart are two rows the reader
        // cannot durably choose between: its matcher is equivalence, so a choice of the
        // second comes back as the first after a relaunch — silently, and with both rows
        // carrying the same label, since a pair this close has one localized name. They
        // collapse, first occurrence winning, which is the very member that search
        // returns. Nothing visible is lost.
        //
        // Keyed on the maximal identifier, which is equivalence spelled as something a
        // Set can hold and the only totally-ordered spelling of it. A difference in
        // writing system survives: Simplified and Traditional Chinese have different
        // maximal identifiers and stay two rows, which is the carve-out that lets a
        // reader who needs Traditional Chinese ask for it.
        var seen = Set<String>()
        let distinct = named.filter { seen.insert($0.language.maximalIdentifier).inserted }

        return distinct.sorted { lhs, rhs in
            let leftRank = rank(lhs.language)
            let rightRank = rank(rhs.language)
            if leftRank != rightRank { return leftRank < rightRank }
            let byName = lhs.name.compare(
                rhs.name,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: displayLocale
            )
            if byName != .orderedSame { return byName == .orderedAscending }
            return lhs.language.maximalIdentifier < rhs.language.maximalIdentifier
        }
        .map(\.language)
    }
}
