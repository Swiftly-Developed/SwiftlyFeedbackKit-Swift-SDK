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
}
