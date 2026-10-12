import Foundation

/// One field of one item, in one confidently detected source language — the atom of the
/// translation pipeline. Units are grouped into ``TranslationBatch``es by source language
/// before dispatch, and round-trip through `TranslationSession` via ``clientIdentifier``.
struct TranslatableUnit: Sendable, Hashable {
    /// The owning item's id — a `Feedback.id` or `Comment.id`.
    let itemID: UUID
    let field: TranslatableField
    let sourceText: String
    let sourceLanguage: Locale.Language

    /// Stable identifier carried on `TranslationSession.Request` and echoed back on the
    /// `Response`, so a translated string can be filed under the right item and field.
    var clientIdentifier: String {
        "\(itemID.uuidString)|\(field.rawValue)"
    }

    /// Inverse of ``clientIdentifier`` for the `Response` round-trip.
    static func parse(clientIdentifier: String) -> (itemID: UUID, field: TranslatableField)? {
        let parts = clientIdentifier.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let itemID = UUID(uuidString: String(parts[0])),
              let field = TranslatableField(rawValue: String(parts[1])) else {
            return nil
        }
        return (itemID, field)
    }
}
