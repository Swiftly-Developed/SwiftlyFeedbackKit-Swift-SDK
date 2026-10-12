import Foundation

/// In-memory cache of translated projections, keyed by item, field, and target language.
///
/// Never persisted anywhere — no defaults store, no files, no scene storage; translations
/// live and die with the process. Each entry carries a fingerprint of the source text it was
/// translated from, so an item whose text changed under a cached translation (an admin
/// edit, a refresh returning new content) misses — and is evicted — instead of serving a
/// stale projection.
struct TranslationCache {
    struct Key: Hashable {
        let itemID: UUID
        let field: TranslatableField
        let target: Locale.Language
    }

    struct Entry {
        let translatedText: String
        /// Hash of the source text at translation time — the content fingerprint.
        let sourceHash: Int
    }

    private var storage: [Key: Entry] = [:]

    /// Body-safe read. Nonmutating, so an `@Observable` owner does not publish when a
    /// view reads the cache. A fingerprint mismatch returns `nil` and leaves the entry
    /// in place. ``lookup`` is the evicting variant and must not run from a view `body`:
    /// calling a `mutating` method write-backs the property and retriggers Observation.
    func peek(itemID: UUID, field: TranslatableField, target: Locale.Language, sourceText: String) -> String? {
        let key = Key(itemID: itemID, field: field, target: target)
        guard let entry = storage[key] else { return nil }
        guard entry.sourceHash == sourceText.hashValue else { return nil }
        return entry.translatedText
    }

    /// Returns the cached translation, or `nil` when absent or when `sourceText` no longer
    /// matches the fingerprint the entry was stored under. A fingerprint mismatch also
    /// **evicts** the stale entry.
    ///
    /// Not safe to call on an `@Observable` property from a view `body` — use ``peek``.
    mutating func lookup(itemID: UUID, field: TranslatableField, target: Locale.Language, sourceText: String) -> String? {
        let key = Key(itemID: itemID, field: field, target: target)
        guard let entry = storage[key] else { return nil }
        guard entry.sourceHash == sourceText.hashValue else {
            storage[key] = nil
            return nil
        }
        return entry.translatedText
    }

    mutating func store(unit: TranslatableUnit, target: Locale.Language, translatedText: String) {
        let key = Key(itemID: unit.itemID, field: unit.field, target: target)
        storage[key] = Entry(translatedText: translatedText, sourceHash: unit.sourceText.hashValue)
    }

    /// Drops every cached field of one item, across all targets.
    mutating func invalidate(itemID: UUID) {
        storage = storage.filter { $0.key.itemID != itemID }
    }

    mutating func invalidateAll() {
        storage.removeAll()
    }
}
