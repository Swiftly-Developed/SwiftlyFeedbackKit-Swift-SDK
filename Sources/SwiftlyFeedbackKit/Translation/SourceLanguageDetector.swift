import Foundation
import NaturalLanguage

/// On-device source-language detection over feedback text.
///
/// Available on **every** platform the package targets, including visionOS — only the
/// Translation framework is platform-gated, not `NaturalLanguage`. Stateless and
/// synchronous; absence of a confident answer is a return value, never a thrown error.
/// Detection is per field, because one item can hold two languages.
struct SourceLanguageDetector {
    /// Minimum probability the top hypothesis must reach before a detection is trusted.
    /// A wrong source language in the affordance label is worse than no affordance.
    static let confidenceThreshold: Double = 0.6

    /// Minimum trimmed character count before detection is attempted — the short-text
    /// gate. Language detection on a three-word title is unreliable.
    static let minimumCharacters: Int = 10

    /// Detects the language of `text`, or `nil` when the text is too short or the top
    /// hypothesis does not clear ``confidenceThreshold``.
    ///
    /// The recognizer is instantiated per call — it is cheap and not `Sendable`, so it is
    /// never stored.
    static func detect(_ text: String) -> Locale.Language? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= minimumCharacters else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= confidenceThreshold else {
            return nil
        }
        return Locale.Language(identifier: language.rawValue)
    }

    /// Per-field detection over a feedback item's translatable text — title, description,
    /// and a non-nil rejection reason. Only confidently detected fields emit units, and
    /// fields already in `target` are not applicable (the original text stands).
    static func units(for feedback: Feedback, target: Locale.Language) -> [TranslatableUnit] {
        var fields: [(TranslatableField, String)] = [
            (.title, feedback.title),
            (.description, feedback.description),
        ]
        if let rejectionReason = feedback.rejectionReason {
            fields.append((.rejectionReason, rejectionReason))
        }
        return fields.compactMap { field, text in
            guard let source = detect(text), source != target else { return nil }
            return TranslatableUnit(itemID: feedback.id, field: field, sourceText: text, sourceLanguage: source)
        }
    }

    /// Detection over a comment's text, or `nil` when detection is not confident or the
    /// comment is already in `target`.
    static func unit(for comment: Comment, target: Locale.Language) -> TranslatableUnit? {
        guard let source = detect(comment.content), source != target else { return nil }
        return TranslatableUnit(itemID: comment.id, field: .commentText, sourceText: comment.content, sourceLanguage: source)
    }
}
