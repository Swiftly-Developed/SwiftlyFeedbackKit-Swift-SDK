import SwiftUI

/// The reader-side translation affordance: a glyph, "Translated from ⟨language⟩", and a
/// toggle between the translation and the original text.
///
/// Platform-neutral by design — it renders only when a mount site hands it data, and on
/// platforms without a usable Translation framework no data ever exists. The unavailable
/// state is this view being **absent** at the mount site, never a disabled control.
/// RTL-safe: layout is one `HStack` with leading/trailing semantics only.
struct TranslationAffordanceView: View {
    let sourceLanguageName: String
    let isShowingOriginal: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "translate")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(Strings.translatedFrom(sourceLanguageName))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 8)

            Button(isShowingOriginal ? Strings.showTranslation : Strings.showOriginal) {
                onToggle()
            }
            .font(.caption)
            .buttonStyle(.borderless)
            .accessibilityHint(Strings.accessibilityTranslationToggleHint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
