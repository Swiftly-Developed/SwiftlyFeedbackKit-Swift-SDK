import Foundation

extension Locale.Language {
    /// The localized display name of this language in `locale` (e.g. "German" for `de`
    /// in an English locale, "Deutsch" in a German one), or `nil` when no name exists.
    ///
    /// A `nil` return means the affordance is **absent** for that item — a raw language
    /// code is never shown as a fallback; absence is the fallback.
    func localizedDisplayName(in locale: Locale) -> String? {
        guard let code = languageCode?.identifier else { return nil }
        return locale.localizedString(forLanguageCode: code)
    }

    /// The name to show for this language in a target picker, in `locale` (e.g. "English
    /// (United Kingdom)"), or `nil` when no name exists.
    ///
    /// Distinct from the affordance's name helper above, and deliberately so: that one
    /// resolves the bare code, which is right for a detected source language and wrong
    /// here, because it renders every regional and script variant with the same word —
    /// two rows reading "Chinese", two reading "Portuguese". This resolves the minimal
    /// identifier, which distinguishes them. A `nil` return means the row is dropped;
    /// a raw code is never shown.
    func localizedTargetName(in locale: Locale) -> String? {
        guard languageCode != nil else { return nil }
        return locale.localizedString(forIdentifier: minimalIdentifier)
    }
}
