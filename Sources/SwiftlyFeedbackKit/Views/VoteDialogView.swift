import SwiftUI

/// The one vote-email dialog, shared by the list and detail surfaces.
/// Hosts differ only in VM type and submit routing, so the dialog takes
/// plain bindings plus a single labeled commit closure — no mode enum.
struct VoteDialogView: View {
    @Binding var email: String
    @Binding var notifyStatusChange: Bool
    @Binding var subscribeToMailingList: Bool
    @Binding var operationalEmails: Bool
    @Binding var marketingEmails: Bool
    let onCommit: (_ email: String?, _ notify: Bool, _ subscribeToMailingList: Bool?, _ mailingListEmailTypes: [String]?) -> Void

    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    // Declared for every platform that compiles the `#if !os(macOS)` presentation
    // block below — visionOS included, or `presentationDetentsForDevice` cannot
    // find it in scope (the visionOS slice never built before 2026-08-15).
    #if os(iOS) || os(visionOS)
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @SwiftUI.Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    var body: some View {
        NavigationStack {
            Form {
                VoteDialogEmailSection(email: $email)
                VoteDialogNotificationSection(
                    email: $email,
                    notifyStatusChange: $notifyStatusChange,
                    subscribeToMailingList: $subscribeToMailingList,
                    operationalEmails: $operationalEmails,
                    marketingEmails: $marketingEmails
                )
            }
            .navigationTitle(String(localized: .voteDialogTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: .voteDialogSkip)) {
                        submitAndDismiss(email: nil, notify: false)
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: .voteDialogSubmit)) {
                        submitAndDismiss(
                            email: email,
                            notify: notifyStatusChange,
                            subscribeToMailingList: subscribeToMailingList,
                            mailingListEmailTypes: selectedEmailTypes()
                        )
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .tint(theme.primaryColor.resolve(for: colorScheme))
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 300)
        #else
        .presentationDetents(presentationDetentsForDevice)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .presentationSizing(.form)
        #endif
    }

    #if !os(macOS)
    private var presentationDetentsForDevice: Set<PresentationDetent> {
        // A fixed 320-pt detent overflows iPhone Duo's outer display in landscape
        // (compact height). Size classes choose the detent; the sheet itself
        // moves clear of the fold.
        if verticalSizeClass == .compact {
            return [.medium, .large]
        }
        if horizontalSizeClass == .compact {
            return [.height(320), .medium]
        }
        return [.medium]
    }
    #endif

    /// Same derivation rule as the view models' `buildVoteEmailTypes()`,
    /// computed from the dialog's own bindings at submit time.
    private func selectedEmailTypes() -> [String]? {
        guard subscribeToMailingList else { return nil }
        var types: [String] = []
        if operationalEmails { types.append("operational") }
        if marketingEmails { types.append("marketing") }
        return types.isEmpty ? nil : types
    }

    private func submitAndDismiss(email: String?, notify: Bool, subscribeToMailingList: Bool? = nil, mailingListEmailTypes: [String]? = nil) {
        dismiss()

        // Save the email to config for future votes (if a valid email was provided)
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validEmail = trimmedEmail, !validEmail.isEmpty {
            SwiftlyFeedback.configuration.userEmail = validEmail
        }

        onCommit(email, notify, subscribeToMailingList, mailingListEmailTypes)
    }
}
