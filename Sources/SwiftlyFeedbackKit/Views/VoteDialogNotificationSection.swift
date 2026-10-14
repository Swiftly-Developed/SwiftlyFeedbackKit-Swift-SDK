import SwiftUI

/// Status-notification and mailing-list toggles for the vote dialog.
struct VoteDialogNotificationSection: View {
    @Binding var email: String
    @Binding var notifyStatusChange: Bool
    @Binding var subscribeToMailingList: Bool
    @Binding var operationalEmails: Bool
    @Binding var marketingEmails: Bool

    private var hasValidEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Section {
            Toggle(isOn: $notifyStatusChange) {
                Text(String(localized: .voteDialogNotifyToggle))
            }
            .disabled(!hasValidEmail)
            .accessibilityHint(String(localized: .accessibilityVoteDialogNotifyHint))
            .onChange(of: email) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notifyStatusChange = false
                }
            }

            if SwiftlyFeedback.configuration.showMailingListOptIn && hasValidEmail {
                Toggle(isOn: $subscribeToMailingList) {
                    Text(String(localized: .mailingListOptIn))
                }

                if subscribeToMailingList {
                    Toggle(isOn: $operationalEmails) {
                        Text(String(localized: .mailingListOperational))
                    }
                    .accessibilityHint(String(localized: .accessibilityMailingListOperationalHint))

                    Toggle(isOn: $marketingEmails) {
                        Text(String(localized: .mailingListMarketing))
                    }
                    .accessibilityHint(String(localized: .accessibilityMailingListMarketingHint))
                }
            }
        } footer: {
            Text(String(localized: .voteDialogNotifyDescription))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
