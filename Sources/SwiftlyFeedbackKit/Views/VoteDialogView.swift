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
    #endif

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var hasValidEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        #if os(macOS)
        macOSContent
        #else
        iOSContent
        #endif
    }

    // MARK: - iOS & iPadOS Content

    #if !os(macOS)
    private var iOSContent: some View {
        NavigationStack {
            Form {
                emailSection
                notificationSection
            }
            .navigationTitle(Strings.voteDialogTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.voteDialogSkip) {
                        submitAndDismiss(email: nil, notify: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.voteDialogSubmit) {
                        submitAndDismiss(
                            email: email,
                            notify: notifyStatusChange,
                            subscribeToMailingList: subscribeToMailingList,
                            mailingListEmailTypes: selectedEmailTypes()
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(theme.primaryColor.resolve(for: colorScheme))
        }
        .presentationDetents(presentationDetentsForDevice)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .interactiveDismissDisabled(false)
        .presentationSizing(.form)
    }

    private var presentationDetentsForDevice: Set<PresentationDetent> {
        // iPhone: Use height-based detent for compact content
        // iPad: .form sizing handles it, but provide medium as fallback
        if horizontalSizeClass == .compact {
            return [.height(320)]
        } else {
            return [.medium]
        }
    }
    #endif

    // MARK: - macOS Content

    #if os(macOS)
    private var macOSContent: some View {
        VStack(spacing: 16) {
            // Header
            Text(Strings.voteDialogTitle)
                .font(.headline)

            // Email field
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.voteDialogEmailHeader)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField(Strings.voteDialogEmailPlaceholder, text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Strings.voteDialogEmailHeader)

                Text(Strings.voteDialogEmailFooter)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Notification toggle
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $notifyStatusChange) {
                    Text(Strings.voteDialogNotifyToggle)
                }
                .disabled(!hasValidEmail)
                .accessibilityHint(Strings.accessibilityVoteDialogNotifyHint)
                .onChange(of: email) { _, newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        notifyStatusChange = false
                    }
                }

                Text(Strings.voteDialogNotifyDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if SwiftlyFeedback.config.showMailingListOptIn && hasValidEmail {
                Toggle(isOn: $subscribeToMailingList) {
                    Text(Strings.mailingListOptIn)
                }

                if subscribeToMailingList {
                    Toggle(isOn: $operationalEmails) {
                        Text(Strings.mailingListOperational)
                    }
                    .padding(.leading, 20)
                    .accessibilityHint(Strings.accessibilityMailingListOperationalHint)

                    Toggle(isOn: $marketingEmails) {
                        Text(Strings.mailingListMarketing)
                    }
                    .padding(.leading, 20)
                    .accessibilityHint(Strings.accessibilityMailingListMarketingHint)
                }
            }

            Spacer()

            Divider()

            // Button bar (HIG: buttons at bottom, Cancel left, Primary right)
            HStack {
                Button(Strings.voteDialogSkip) {
                    submitAndDismiss(email: nil, notify: false)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(Strings.voteDialogSubmit) {
                    submitAndDismiss(
                        email: email,
                        notify: notifyStatusChange,
                        subscribeToMailingList: subscribeToMailingList,
                        mailingListEmailTypes: selectedEmailTypes()
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryColor.resolve(for: colorScheme))
            }
        }
        .padding(20)
        .frame(width: 380, height: 300)
    }
    #endif

    // MARK: - Shared Sections

    private var emailSection: some View {
        Section {
            TextField(Strings.voteDialogEmailPlaceholder, text: $email)
                .textContentType(.emailAddress)
                #if !os(macOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .accessibilityLabel(Strings.voteDialogEmailHeader)
        } header: {
            Text(Strings.voteDialogEmailHeader)
        } footer: {
            Text(Strings.voteDialogEmailFooter)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle(isOn: $notifyStatusChange) {
                Text(Strings.voteDialogNotifyToggle)
            }
            .disabled(!hasValidEmail)
            .accessibilityHint(Strings.accessibilityVoteDialogNotifyHint)
            .onChange(of: email) { _, newValue in
                // Auto-disable notification if email is cleared
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    notifyStatusChange = false
                }
            }

            if SwiftlyFeedback.config.showMailingListOptIn && hasValidEmail {
                Toggle(isOn: $subscribeToMailingList) {
                    Text(Strings.mailingListOptIn)
                }

                if subscribeToMailingList {
                    Toggle(isOn: $operationalEmails) {
                        Text(Strings.mailingListOperational)
                    }
                    .padding(.leading, 20)
                    .accessibilityHint(Strings.accessibilityMailingListOperationalHint)

                    Toggle(isOn: $marketingEmails) {
                        Text(Strings.mailingListMarketing)
                    }
                    .padding(.leading, 20)
                    .accessibilityHint(Strings.accessibilityMailingListMarketingHint)
                }
            }
        } footer: {
            Text(Strings.voteDialogNotifyDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

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
            SwiftlyFeedback.config.userEmail = validEmail
        }

        onCommit(email, notify, subscribeToMailingList, mailingListEmailTypes)
    }
}
