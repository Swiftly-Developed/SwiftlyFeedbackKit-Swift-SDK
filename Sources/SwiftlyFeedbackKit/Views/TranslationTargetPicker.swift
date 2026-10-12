import SwiftUI

/// The reader's translation-target control: a language, or *device language*.
///
/// **Deliberately dumb** (`TRANSLATION01` §18): it receives an already-ordered set and a
/// binding, and computes no ordering of its own. It holds no preference of its own,
/// awaits nothing, and imports no framework — so it compiles on every SDK platform
/// including visionOS.
///
/// **Absent, never disabled.** With an empty set this view renders nothing at all — its
/// own separator included — which is the `UI00` §18.3 contract and is how a platform
/// with no translation support ends up with no control rather than a dead one. The
/// separator lives here, and not at the mount site, precisely so that absence is total:
/// a separator owned by the menu would survive as a stray rule above nothing.
///
/// Every row is tagged with the *wrapped optional* type of the binding. A bare tag of the
/// unwrapped type compiles and yields a control that never shows a selection, which is
/// the one defect a relaunch makes visible and no compiler ever will.
struct TranslationTargetPicker: View {
    /// Already in reading order. The caller orders; this view renders.
    let targets: [Locale.Language]
    /// `nil` means *follow the device language*.
    @Binding var selection: Locale.Language?
    /// The locale the row names are rendered in — the same locale the ordering used,
    /// passed rather than read from the environment so the two cannot disagree.
    let displayLocale: Locale

    var body: some View {
        if !targets.isEmpty {
            Divider()

            Picker(selection: $selection) {
                Text(String(localized: .translationTargetDeviceLanguage))
                    .tag(nil as Locale.Language?)

                ForEach(targets, id: \.self) { language in
                    // A language with no localized name is skipped rather than shown as a
                    // raw code. The ordering has already dropped these, so this is a
                    // second line of defence, not a live branch.
                    if let name = language.localizedTargetName(in: displayLocale) {
                        Text(name).tag(language as Locale.Language?)
                    }
                }
            } label: {
                Label(String(localized: .translationTargetPickerLabel), systemImage: "translate")
            }
        }
    }
}
