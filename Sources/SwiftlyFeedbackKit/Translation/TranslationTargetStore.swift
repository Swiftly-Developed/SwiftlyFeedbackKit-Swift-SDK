import Foundation

/// The reader's chosen translation target, persisted across launches.
///
/// A preference, never content: exactly one namespaced string — a language identifier —
/// is written to the host's defaults. The in-memory translation cache is unchanged and
/// is still never persisted (`TRANSLATION01` §3, §11.4).
///
/// **Deliberately plain.** No `@Observable`, no reference to a translator, nothing async.
/// The view owns the selection state and drives the invalidate-and-re-enqueue sequence;
/// this type only reads and writes one value.
///
/// The defaults store is injected so a test can hand it a scratch domain. Passing nothing
/// uses the process store, which is what the shipping call sites do.
struct TranslationTargetStore {

    /// Namespaced so the SDK can never collide with a host app's own keys, mirroring the
    /// sort-order key the package already writes from the list view model.
    static let defaultsKey = "com.swiftlyfeedback.sdk.translationTarget"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The stored choice, resolved against what the device actually offers.
    ///
    /// Returns the **member of `supported`** that the stored value names, never a value
    /// rebuilt from the stored string: two `Locale.Language` values that mean the same
    /// language are not `==` unless their identifiers match component for component, so a
    /// rebuilt value would fail to select its own row in a picker whose rows are tagged
    /// with the device's own set.
    ///
    /// `nil` when the reader has never chosen, when the stored string names nothing the
    /// device offers, and when it names nothing at all — one debug line, carrying the
    /// identifier and nothing else.
    func storedTarget(in supported: [Locale.Language]) -> Locale.Language? {
        guard let identifier = defaults.string(forKey: Self.defaultsKey), !identifier.isEmpty else {
            return nil
        }
        let stored = Locale.Language(identifier: identifier)
        guard let match = supported.first(where: { stored.isEquivalent(to: $0) }) else {
            SDKLogger.debug("Translation target ignored, not offered on this device: \(identifier)")
            return nil
        }
        return match
    }

    /// The target to translate toward: the reader's choice when it is usable, otherwise
    /// the language of the environment locale — which is exactly today's behaviour, so an
    /// install that has never chosen is unaffected.
    ///
    /// **No product caller until the detail view is wired.** A surface that owns the
    /// reader's control keeps the choice in view state and seeds it from the read above;
    /// this is the entry point for a surface that owns no control and only needs the
    /// answer. It has a test caller today and a product caller one phase from now — an
    /// audit reaching for it as dead code should read this paragraph first.
    func resolvedTarget(locale: Locale, supported: [Locale.Language]) -> Locale.Language {
        storedTarget(in: supported) ?? locale.language
    }

    /// Records a choice; `nil` clears it and restores following the device.
    ///
    /// The caller invalidates the translator afterwards. This type performs no translation
    /// work and holds no reference to one.
    func setTarget(_ language: Locale.Language?) {
        guard let language, language.languageCode != nil else {
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        defaults.set(language.minimalIdentifier, forKey: Self.defaultsKey)
    }
}
