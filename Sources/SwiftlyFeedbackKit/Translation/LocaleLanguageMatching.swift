import Foundation

extension Locale.Language {
    /// Whether the receiver and `other` name the same language, disregarding region but
    /// respecting a difference in writing system.
    ///
    /// Whole-value equality does not answer this question: a reader on a US-English device
    /// looking at British-English text is reading their own language, yet the two values are
    /// unequal — and the framework never supports a language to itself, so the pair can only
    /// fail. Region is therefore ignored.
    ///
    /// **A difference in writing system is a real difference and is respected.** Two texts can
    /// share a language code and still be unreadable to each other; Simplified and Traditional
    /// Chinese are the shipped case. When both values carry a writing system the two must
    /// match; when either does not, the language code alone decides. Note that Foundation
    /// supplies a likely writing system even for an identifier that names none, so the second
    /// branch is measured unreachable today — it is kept because it is the semantics of record.
    ///
    /// **A language carrying no code matches nothing, including another codeless language.** The
    /// answer is therefore not reflexive for such a value, and that is deliberate: the only
    /// callers discard a unit when this answers `true`, so answering `true` for a language
    /// nobody could identify would silently drop work that should have been dispatched. An
    /// unidentifiable language is not evidence of sameness.
    func isSameLanguage(as other: Locale.Language) -> Bool {
        guard let code = languageCode, let otherCode = other.languageCode, code == otherCode else {
            return false
        }
        guard let script, let otherScript = other.script else { return true }
        return script == otherScript
    }
}
