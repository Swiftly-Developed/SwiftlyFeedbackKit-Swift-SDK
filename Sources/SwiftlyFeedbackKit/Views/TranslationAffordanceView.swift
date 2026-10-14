import SwiftUI

/// The reader-side translation affordance: a glyph, a line naming the language the text
/// came from, and a toggle between the translation and the original text.
///
/// The line has two forms. When the reader is reading in their device language the copy
/// names only the source; when they have chosen some other target, it names the pair,
/// because "translated from German" alone no longer says what they are looking at.
///
/// Platform-neutral by design — it renders only when a mount site hands it data, and on
/// platforms without a usable Translation framework no data ever exists. The unavailable
/// state is this view being **absent** at the mount site, never a disabled control.
/// RTL-safe: layout is one `HStack` with leading/trailing semantics only.
struct TranslationAffordanceView: View {
    let sourceLanguageName: String
    /// The reader's chosen target, localized — `nil` when the target IS the device
    /// language, which selects the existing one-argument copy. Naming the target is
    /// only informative when it is not the obvious one (`TRANSLATION01` §14.2).
    ///
    /// Deliberately **not** defaulted: every mount site has to be visited by the
    /// compiler, so an unmigrated one cannot silently keep the one-argument copy.
    let targetLanguageName: String?
    let isShowingOriginal: Bool
    let onToggle: () -> Void

    var body: some View {
        // Two `let`s bound inside `body` — the shape AGENTS.md sanctions for content
        // rendered in more than one form, and the alternative to a banned helper.
        //
        // The visible form is an arrow, which VoiceOver either skips or reads as the
        // word for the glyph; the spoken form is a sentence in its own catalog key.
        // In the device-language case the two are the same string by construction,
        // so the spoken fallback is `displayed` itself rather than a second lookup.
        let displayed = targetLanguageName.map {
            String(localized: .translationTranslatedFromTo(sourceLanguageName, $0))
        } ?? String(localized: .translationTranslatedFrom(sourceLanguageName))
        let spoken = targetLanguageName.map {
            String(localized: .accessibilityTranslationTranslatedFromTo(sourceLanguageName, $0))
        } ?? displayed

        HStack(spacing: 6) {
            Image(systemName: "translate")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(displayed)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .accessibilityLabel(spoken)

            Spacer(minLength: 8)

            Button(isShowingOriginal ? String(localized: .translationShowTranslation) : String(localized: .translationShowOriginal)) {
                onToggle()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityHint(String(localized: .accessibilityTranslationToggleHint))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
