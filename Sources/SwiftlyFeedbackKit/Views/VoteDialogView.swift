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
        #if os(macOS)
        macOSBody
        #else
        sheetBody
        #endif
    }

    #if os(macOS)
    /// A native macOS sheet: a header, a grouped form, and Skip / Vote bottom-right.
    private var macOSBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: .voteDialogTitle))
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .accessibilityAddTraits(.isHeader)

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
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)
            .tint(theme.primaryColor.resolve(for: colorScheme))

            HStack(spacing: 8) {
                Spacer()
                // A standard push button. The host tint stays off it: a tinted `.bordered`
                // button draws as a pale tinted pill beside the prominent Vote.
                Button(String(localized: .voteDialogSkip)) {
                    submitAndDismiss(email: nil, notify: false)
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button(String(localized: .voteDialogSubmit)) {
                    submitAndDismiss(
                        email: email,
                        notify: notifyStatusChange,
                        subscribeToMailingList: subscribeToMailingList,
                        mailingListEmailTypes: selectedEmailTypes()
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.primaryColor.resolve(for: colorScheme))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .frame(width: 440)
        // Escape is Skip. The sheet otherwise closes itself on Escape before Skip's
        // `.cancelAction` shortcut runs, and no vote is cast.
        .onExitCommand {
            submitAndDismiss(email: nil, notify: false)
        }
    }
    #endif

    private var sheetBody: some View {
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
        #if !os(macOS)
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
