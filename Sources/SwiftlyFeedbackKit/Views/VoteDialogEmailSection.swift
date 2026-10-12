import SwiftUI

/// Email field for the vote dialog. Shared by every platform so the sheet
/// uses a form instead of a hand-built stack.
struct VoteDialogEmailSection: View {
    @Binding var email: String

    var body: some View {
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
    }
}
