import SwiftUI

struct SettingsView: View {
    @Bindable var authViewModel: AuthViewModel
    var projectViewModel: ProjectViewModel?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var subscriptionService = SubscriptionService.shared
    @State private var showingLogoutConfirmation = false
    @State private var showingChangePassword = false
    @State private var showingDeleteAccount = false
    #if os(iOS)
    @State private var showingDeveloperCommands = false
    #endif
    @State private var showingSubscription = false
    @State private var pendingLogout = false

    var body: some View {
        settingsContent
            .navigationTitle("Settings")
            .sheet(isPresented: $showingChangePassword) {
                ChangePasswordView(authViewModel: authViewModel) {
                    pendingLogout = true
                }
                #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                #endif
            }
            .sheet(isPresented: $showingDeleteAccount) {
                DeleteAccountView(authViewModel: authViewModel) {
                    pendingLogout = true
                }
                #if os(iOS)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                #endif
            }
            #if os(iOS)
            .sheet(isPresented: $showingDeveloperCommands) {
                if let projectViewModel = projectViewModel {
                    DeveloperCommandsView(projectViewModel: projectViewModel)
                }
            }
            #endif
            .onChange(of: showingChangePassword) { _, isShowing in
                if !isShowing && pendingLogout {
                    pendingLogout = false
                    authViewModel.forceLogout()
                }
            }
            .onChange(of: showingDeleteAccount) { _, isShowing in
                if !isShowing && pendingLogout {
                    pendingLogout = false
                    authViewModel.forceLogout()
                }
            }
            .confirmationDialog(
                "Sign Out",
                isPresented: $showingLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authViewModel.logout()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out of your account?")
            }
            .alert("Error", isPresented: $authViewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authViewModel.errorMessage ?? "An unexpected error occurred")
            }
    }

    @ViewBuilder
    private var settingsContent: some View {
        Form {
            // Profile Section
            profileSection

            // Subscription Section
            subscriptionSection

            // Notifications Section
            notificationsSection

            // Security Section
            securitySection

            // About Section
            aboutSection

            // Developer Commands (DEBUG or TestFlight only, iOS only - macOS uses menu)
            #if os(iOS)
            if AppEnvironment.isDeveloperMode, let projectViewModel = projectViewModel {
                developerSection(projectViewModel: projectViewModel)
            }
            #endif

            // Sign Out Section
            signOutSection

            // Danger Zone Section
            dangerZoneSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        #endif
    }

    // MARK: - Profile Section

    @ViewBuilder
    private var profileSection: some View {
        Section {
            if let user = authViewModel.currentUser {
                HStack(spacing: 16) {
                    ProfileAvatarView(name: user.name, size: 60)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(user.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if user.isAdmin {
                            Label("Administrator", systemImage: "checkmark.shield.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.top, 2)
                        }
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Subscription Section

    @ViewBuilder
    private var subscriptionSection: some View {
        Section {
            NavigationLink {
                SubscriptionView()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        subscriptionGradient
                    }
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        Image(systemName: subscriptionIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(subscriptionService.isPaidSubscriber ? .white : .gray)
                    }

                    Text("Subscription")
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(subscriptionService.subscriptionStatusText)
                        .foregroundStyle(.secondary)

                    if subscriptionService.isPaidSubscriber {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }
            }
        } header: {
            Text("Subscription")
        } footer: {
            if subscriptionService.isPaidSubscriber {
                if let expirationDate = subscriptionService.subscriptionExpirationDate {
                    if subscriptionService.willRenew {
                        Text("Your subscription renews on \(expirationDate.formatted(date: .abbreviated, time: .omitted)).")
                    } else {
                        Text("Your subscription expires on \(expirationDate.formatted(date: .abbreviated, time: .omitted)).")
                    }
                }
            } else {
                Text("Upgrade to Pro or Team for unlimited feedback, integrations, and more.")
            }
        }
    }

    @ViewBuilder
    private var subscriptionGradient: some View {
        switch subscriptionService.currentTier {
        case .free:
            Color.gray.opacity(0.3)
        case .pro:
            LinearGradient(
                colors: [.purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .team:
            LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var subscriptionIcon: String {
        switch subscriptionService.currentTier {
        case .free: return "crown"
        case .pro: return "crown.fill"
        case .team: return "person.3.fill"
        }
    }

    // MARK: - Notifications Section

    @ViewBuilder
    private var notificationsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { authViewModel.currentUser?.notifyNewFeedback ?? true },
                set: { newValue in
                    Task {
                        await authViewModel.updateNotificationSettings(
                            notifyNewFeedback: newValue,
                            notifyNewComments: nil
                        )
                    }
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Feedback")
                        Text("Receive email when users submit feedback")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Toggle(isOn: Binding(
                get: { authViewModel.currentUser?.notifyNewComments ?? true },
                set: { newValue in
                    Task {
                        await authViewModel.updateNotificationSettings(
                            notifyNewFeedback: nil,
                            notifyNewComments: newValue
                        )
                    }
                }
            )) {
                HStack(spacing: 12) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.green, in: RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Comments")
                        Text("Receive email when comments are added")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Email notifications for your projects.")
        }
    }

    // MARK: - Security Section

    @ViewBuilder
    private var securitySection: some View {
        Section {
            Button {
                showingChangePassword = true
            } label: {
                SettingsRowView(
                    icon: "key.fill",
                    iconColor: .orange,
                    title: "Change Password",
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        } header: {
            Text("Security")
        } footer: {
            Text("We recommend using a strong, unique password.")
        }
    }

    // MARK: - About Section

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            SettingsInfoRowView(
                icon: "info.circle.fill",
                iconColor: .blue,
                title: "Version",
                value: appVersion
            )

            SettingsInfoRowView(
                icon: "hammer.fill",
                iconColor: .gray,
                title: "Build",
                value: appBuild
            )

            SettingsInfoRowView(
                icon: "server.rack",
                iconColor: .purple,
                title: "Server",
                value: "localhost:8080"
            )
        }
    }

    // MARK: - Sign Out Section

    @ViewBuilder
    private var signOutSection: some View {
        Section {
            Button {
                showingLogoutConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - Danger Zone Section

    @ViewBuilder
    private var dangerZoneSection: some View {
        Section {
            Button {
                showingDeleteAccount = true
            } label: {
                SettingsRowView(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "Delete Account",
                    titleColor: .red,
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        } header: {
            Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
        } footer: {
            Text("Permanently delete your account and all associated data. Projects you own with no other members will be archived.")
        }
    }

    // MARK: - Developer Section (iOS only - macOS uses menu)

    #if os(iOS)
    @ViewBuilder
    private func developerSection(projectViewModel: ProjectViewModel) -> some View {
        Section {
            Button {
                showingDeveloperCommands = true
            } label: {
                SettingsRowView(
                    icon: "hammer.fill",
                    iconColor: .orange,
                    title: "Developer Commands",
                    showChevron: true
                )
            }
            .buttonStyle(.plain)
        } header: {
            Label("Developer", systemImage: "wrench.and.screwdriver.fill")
                .foregroundStyle(.orange)
                .font(.footnote)
                .fontWeight(.semibold)
                .textCase(.uppercase)
        } footer: {
            Text(AppEnvironment.isDebug ? "DEBUG build detected" : "TestFlight build detected")
        }
    }
    #endif

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Profile Avatar View

struct ProfileAvatarView: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let components = name.split(separator: " ")
        let firstInitial = components.first?.prefix(1) ?? ""
        let lastInitial = components.count > 1 ? components.last?.prefix(1) ?? "" : ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Settings Row View

struct SettingsRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    var titleColor: Color = .primary
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 6))

            Text(title)
                .foregroundStyle(titleColor)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Settings Info Row View

struct SettingsInfoRowView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 6))

            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @Bindable var authViewModel: AuthViewModel
    var onSuccessfulChange: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var localError: String?

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case current, new, confirm
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current Password", text: $currentPassword)
                        .focused($focusedField, equals: .current)
                        #if os(iOS)
                        .textContentType(.password)
                        #endif
                } header: {
                    Text("Verify Identity")
                } footer: {
                    Text("Enter your current password to continue.")
                }

                Section {
                    SecureField("New Password", text: $newPassword)
                        .focused($focusedField, equals: .new)
                        #if os(iOS)
                        .textContentType(.newPassword)
                        #endif

                    SecureField("Confirm Password", text: $confirmPassword)
                        .focused($focusedField, equals: .confirm)
                        #if os(iOS)
                        .textContentType(.newPassword)
                        #endif
                } header: {
                    Text("New Password")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        PasswordRequirementView(
                            text: "At least 8 characters",
                            isMet: newPassword.count >= 8
                        )
                        PasswordRequirementView(
                            text: "Passwords match",
                            isMet: !confirmPassword.isEmpty && newPassword == confirmPassword
                        )
                    }
                    .padding(.top, 4)
                }

                if let error = localError ?? (authViewModel.showError ? authViewModel.errorMessage : nil) {
                    Section {
                        ErrorBannerView(message: error)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Change Password")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        changePassword()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || authViewModel.isLoading)
                }
            }
            .interactiveDismissDisabled(authViewModel.isLoading)
            .overlay {
                if authViewModel.isLoading {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .onAppear {
                focusedField = .current
            }
        }
    }

    private var isValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 8 &&
        newPassword == confirmPassword &&
        currentPassword != newPassword
    }

    private func changePassword() {
        localError = nil

        guard newPassword == confirmPassword else {
            localError = "Passwords do not match"
            focusedField = .confirm
            return
        }

        guard newPassword.count >= 8 else {
            localError = "Password must be at least 8 characters"
            focusedField = .new
            return
        }

        guard currentPassword != newPassword else {
            localError = "New password must be different from current password"
            focusedField = .new
            return
        }

        Task {
            let success = await authViewModel.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            if success {
                // Notify parent that password was changed successfully
                onSuccessfulChange()
                dismiss()
            }
        }
    }
}

// MARK: - Password Requirement View

struct PasswordRequirementView: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isMet ? .green : .secondary)
                .font(.system(size: 12))

            Text(text)
                .font(.caption)
                .foregroundStyle(isMet ? .primary : .secondary)
        }
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.red, in: RoundedRectangle(cornerRadius: 6))

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Delete Account View

struct DeleteAccountView: View {
    @Bindable var authViewModel: AuthViewModel
    var onSuccessfulDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var confirmText = ""
    @State private var localError: String?

    @FocusState private var isPasswordFocused: Bool

    private let confirmationPhrase = "DELETE"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Warning Header
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, options: .repeating)

                    Text("Delete Account")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("This action is permanent and cannot be undone. All your data will be deleted.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.05))

                Form {
                    Section {
                        SecureField("Enter your password", text: $password)
                            .focused($isPasswordFocused)
                            #if os(iOS)
                            .textContentType(.password)
                            #endif
                    } header: {
                        Text("Password")
                    }

                    Section {
                        TextField("Type \(confirmationPhrase) to confirm", text: $confirmText)
                            #if os(iOS)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            #endif
                    } header: {
                        Text("Confirmation")
                    } footer: {
                        Text("Type **\(confirmationPhrase)** to confirm you want to delete your account.")
                    }

                    if let error = localError ?? (authViewModel.showError ? authViewModel.errorMessage : nil) {
                        Section {
                            ErrorBannerView(message: error)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            deleteAccount()
                        } label: {
                            HStack {
                                Spacer()
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Label("Delete My Account", systemImage: "trash.fill")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!isValid || authViewModel.isLoading)
                    }
                }
                .formStyle(.grouped)
            }
            .navigationTitle("Delete Account")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(authViewModel.isLoading)
            .onAppear {
                isPasswordFocused = true
            }
        }
    }

    private var isValid: Bool {
        !password.isEmpty && confirmText.uppercased() == confirmationPhrase
    }

    private func deleteAccount() {
        localError = nil

        guard !password.isEmpty else {
            localError = "Please enter your password"
            return
        }

        guard confirmText.uppercased() == confirmationPhrase else {
            localError = "Please type \(confirmationPhrase) to confirm"
            return
        }

        Task {
            let success = await authViewModel.deleteAccount(password: password)
            if success {
                // Notify parent that account was deleted successfully
                onSuccessfulDelete()
                dismiss()
            }
        }
    }
}

// MARK: - Previews

#Preview("Settings") {
    SettingsView(authViewModel: AuthViewModel())
}

#Preview("Change Password") {
    ChangePasswordView(authViewModel: AuthViewModel()) {}
}

#Preview("Delete Account") {
    DeleteAccountView(authViewModel: AuthViewModel()) {}
}
