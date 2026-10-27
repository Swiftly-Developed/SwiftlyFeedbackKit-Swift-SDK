import SwiftUI

/// Email field for the vote dialog. Shared by every platform so the sheet
/// uses a form instead of a hand-built stack.
struct VoteDialogEmailSection: View {
    @Binding var email: String

    var body: some View {
        #if os(macOS)
        // macOS: the label sits in the form's label column and the placeholder is the
        // field's prompt, instead of a header above and a stray label beside it.
        Section {
            TextField(
                String(localized: .voteDialogEmailHeader),
                text: $email,
                prompt: Text(String(localized: .voteDialogEmailPlaceholder))
            )
            .textContentType(.emailAddress)
            .autocorrectionDisabled()
        } footer: {
            Text(String(localized: .voteDialogEmailFooter))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        Section {
            TextField(String(localized: .voteDialogEmailPlaceholder), text: $email)
                .textContentType(.emailAddress)
                #if !os(macOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .accessibilityLabel(String(localized: .voteDialogEmailHeader))
        } header: {
            Text(String(localized: .voteDialogEmailHeader))
        } footer: {
            Text(String(localized: .voteDialogEmailFooter))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        #endif
    }
}
