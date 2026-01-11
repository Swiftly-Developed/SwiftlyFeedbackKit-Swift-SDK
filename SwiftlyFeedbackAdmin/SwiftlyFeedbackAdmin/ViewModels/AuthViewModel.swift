import SwiftUI

@MainActor
@Observable
final class AuthViewModel {
    var isAuthenticated = false
    var currentUser: User?
    var isLoading = false
    var errorMessage: String?
    var showError = false

    /// Whether the initial auth state check is in progress.
    /// Views should wait for this to be false before making API calls.
    var isCheckingAuthState = true

    // Login fields
    var loginEmail = ""
    var loginPassword = ""

    // Signup fields
    var signupEmail = ""
    var signupName = ""
    var signupPassword = ""
    var signupConfirmPassword = ""

    // Email verification
    var verificationCode = ""

    // Password reset
    var resetEmail = ""
    var resetCode = ""
    var resetNewPassword = ""
    var resetConfirmPassword = ""
    var resetEmailSent = false

    // Keep me signed in
    var keepMeSignedIn: Bool {
        get { SecureStorageManager.shared.keepMeSignedIn }
        set { SecureStorageManager.shared.keepMeSignedIn = newValue }
    }

    var needsEmailVerification: Bool {
        let needs = isAuthenticated && currentUser?.isEmailVerified == false
        AppLogger.viewModel.debug("🔍 needsEmailVerification: \(needs) (isAuthenticated: \(self.isAuthenticated), isEmailVerified: \(self.currentUser?.isEmailVerified ?? false))")
        return needs
    }

    init() {
        AppLogger.viewModel.info("AuthViewModel initialized")
        // Check if user is already logged in
        checkAuthState()
    }

    func checkAuthState() {
        AppLogger.viewModel.info("🔄 Checking auth state...")
        isCheckingAuthState = true
        Task {
            defer { isCheckingAuthState = false }

            // Ensure AdminAPIClient has the correct base URL before making any requests
            await AdminAPIClient.shared.initializeBaseURL()

            if SecureStorageManager.shared.authToken != nil {
                AppLogger.viewModel.info("🔑 Token found in keychain, fetching current user...")
                do {
                    currentUser = try await AuthService.shared.getCurrentUser()
                    isAuthenticated = true
                    AppLogger.viewModel.info("✅ Auth state restored - user: \(self.currentUser?.id.uuidString ?? "nil"), isEmailVerified: \(self.currentUser?.isEmailVerified ?? false)")

                    // Sync subscription service with user ID
                    if let userId = currentUser?.id {
                        await SubscriptionService.shared.login(userId: userId)
                    }
                } catch {
                    AppLogger.viewModel.error("❌ Failed to restore auth state: \(error.localizedDescription)")
                    // Token invalid or expired - try auto re-login if credentials are saved
                    SecureStorageManager.shared.authToken = nil

                    if await attemptAutoReLogin() {
                        AppLogger.viewModel.info("✅ Auto re-login successful")
                    } else {
                        isAuthenticated = false
                        AppLogger.viewModel.info("🔑 Invalid token deleted from keychain, no saved credentials for auto re-login")
                    }
                }
            } else {
                AppLogger.viewModel.info("🔑 No token in keychain - checking for saved credentials...")
                // No token, but maybe we have saved credentials from "keep me signed in"
                if await attemptAutoReLogin() {
                    AppLogger.viewModel.info("✅ Auto re-login successful with saved credentials")
                } else {
                    AppLogger.viewModel.info("🔑 No saved credentials - user not authenticated")
                }
            }
        }
    }

    func login() async {
        AppLogger.viewModel.info("🔐 Login attempt for: \(self.loginEmail)")
        guard !loginEmail.isEmpty, !loginPassword.isEmpty else {
            AppLogger.viewModel.warning("⚠️ Login validation failed - empty fields")
            showError(message: "Please enter email and password")
            return
        }

        isLoading = true
        errorMessage = nil

        // Store credentials before clearing fields (for saving after success)
        let emailToSave = loginEmail
        let passwordToSave = loginPassword

        do {
            let response = try await AuthService.shared.login(
                email: loginEmail,
                password: loginPassword
            )
            currentUser = response.user
            isAuthenticated = true
            AppLogger.viewModel.info("✅ Login successful - isEmailVerified: \(response.user.isEmailVerified)")

            // Save credentials if keep me signed in is enabled
            SecureStorageManager.shared.saveCredentialsIfEnabled(email: emailToSave, password: passwordToSave)

            clearLoginFields()

            // Sync subscription service with user ID
            await SubscriptionService.shared.login(userId: response.user.id)
        } catch {
            AppLogger.viewModel.error("❌ Login failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func signup() async {
        AppLogger.viewModel.info("📝 Signup attempt for: \(self.signupEmail)")
        guard !signupEmail.isEmpty, !signupName.isEmpty, !signupPassword.isEmpty else {
            AppLogger.viewModel.warning("⚠️ Signup validation failed - empty fields")
            showError(message: "Please fill in all fields")
            return
        }

        guard signupPassword == signupConfirmPassword else {
            AppLogger.viewModel.warning("⚠️ Signup validation failed - passwords don't match")
            showError(message: "Passwords do not match")
            return
        }

        guard signupPassword.count >= 8 else {
            AppLogger.viewModel.warning("⚠️ Signup validation failed - password too short")
            showError(message: "Password must be at least 8 characters")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.signup(
                email: signupEmail,
                name: signupName,
                password: signupPassword
            )
            currentUser = response.user
            isAuthenticated = true
            AppLogger.viewModel.info("✅ Signup successful - isEmailVerified: \(response.user.isEmailVerified)")
            clearSignupFields()

            // Sync subscription service with user ID
            await SubscriptionService.shared.login(userId: response.user.id)
        } catch {
            AppLogger.viewModel.error("❌ Signup failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func logout() async {
        AppLogger.viewModel.info("🚪 Logout initiated")
        isLoading = true

        do {
            try await AuthService.shared.logout()
            AppLogger.viewModel.info("✅ Logout successful")
        } catch {
            AppLogger.viewModel.warning("⚠️ Logout error (ignoring): \(error.localizedDescription)")
            // Ignore logout errors
        }

        // Logout from subscription service
        await SubscriptionService.shared.logout()

        // Clear saved credentials on explicit logout
        SecureStorageManager.shared.clearSavedCredentials()

        currentUser = nil
        isAuthenticated = false
        isLoading = false
        AppLogger.viewModel.info("🔄 Auth state cleared")
    }

    private func showError(message: String) {
        AppLogger.viewModel.error("⚠️ Showing error to user: \(message)")
        errorMessage = message
        showError = true
    }

    /// Attempts to re-login using saved credentials.
    /// Returns true if successful, false otherwise.
    func attemptAutoReLogin() async -> Bool {
        guard let credentials = SecureStorageManager.shared.getSavedCredentials() else {
            AppLogger.viewModel.info("🔐 No saved credentials for auto re-login")
            return false
        }

        AppLogger.viewModel.info("🔐 Attempting auto re-login with saved credentials...")

        do {
            let response = try await AuthService.shared.login(
                email: credentials.email,
                password: credentials.password
            )
            currentUser = response.user
            isAuthenticated = true
            AppLogger.viewModel.info("✅ Auto re-login successful - user: \(response.user.id)")

            // Sync subscription service with user ID
            await SubscriptionService.shared.login(userId: response.user.id)
            return true
        } catch {
            AppLogger.viewModel.error("❌ Auto re-login failed: \(error.localizedDescription)")
            // Clear saved credentials since they didn't work (e.g., password changed)
            SecureStorageManager.shared.clearSavedCredentials()
            return false
        }
    }

    /// Handles a 401 unauthorized error by attempting auto re-login.
    /// Call this when an API request fails with unauthorized error.
    /// - Parameter retryAction: Optional closure to retry the original action after successful re-login
    /// - Returns: True if auto re-login succeeded (and retryAction was called if provided), false otherwise
    @discardableResult
    func handleUnauthorizedError(retryAction: (() async throws -> Void)? = nil) async -> Bool {
        AppLogger.viewModel.info("🔐 Handling unauthorized error...")

        // Clear the invalid token
        SecureStorageManager.shared.authToken = nil

        // Attempt auto re-login
        if await attemptAutoReLogin() {
            // If we have a retry action, execute it
            if let retryAction = retryAction {
                do {
                    try await retryAction()
                    AppLogger.viewModel.info("✅ Retry action succeeded after auto re-login")
                } catch {
                    AppLogger.viewModel.error("❌ Retry action failed after auto re-login: \(error.localizedDescription)")
                }
            }
            return true
        } else {
            // Auto re-login failed, user needs to log in manually
            isAuthenticated = false
            currentUser = nil
            AppLogger.viewModel.info("🔐 Auto re-login failed, user needs to log in manually")
            return false
        }
    }

    private func clearLoginFields() {
        loginEmail = ""
        loginPassword = ""
    }

    private func clearSignupFields() {
        signupEmail = ""
        signupName = ""
        signupPassword = ""
        signupConfirmPassword = ""
    }

    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        AppLogger.viewModel.info("🔄 Password change initiated")
        isLoading = true
        errorMessage = nil

        do {
            try await AuthService.shared.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            AppLogger.viewModel.info("✅ Password changed successfully")
            // Password changed successfully - don't change auth state here
            // Let the caller dismiss sheets first, then call forceLogout()
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Password change failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func forceLogout() {
        AppLogger.viewModel.info("🚪 Force logout")
        currentUser = nil
        isAuthenticated = false
    }

    func deleteAccount(password: String) async -> Bool {
        AppLogger.viewModel.info("🗑️ Account deletion initiated")
        isLoading = true
        errorMessage = nil

        do {
            try await AuthService.shared.deleteAccount(password: password)
            AppLogger.viewModel.info("✅ Account deleted successfully")
            // Account deleted successfully - don't change auth state here
            // Let the caller dismiss sheets first, then call forceLogout()
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Account deletion failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func verifyEmail() async {
        AppLogger.viewModel.info("✉️ Email verification initiated with code: \(self.verificationCode)")
        guard verificationCode.count == 8 else {
            AppLogger.viewModel.warning("⚠️ Invalid verification code length: \(self.verificationCode.count)")
            showError(message: "Please enter the 8-character verification code")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AuthService.shared.verifyEmail(code: verificationCode)
            AppLogger.viewModel.info("✅ Email verified - updating currentUser")
            AppLogger.viewModel.info("📊 Before update: currentUser.isEmailVerified = \(self.currentUser?.isEmailVerified ?? false)")
            currentUser = response.user
            AppLogger.viewModel.info("📊 After update: currentUser.isEmailVerified = \(self.currentUser?.isEmailVerified ?? false)")
            verificationCode = ""
        } catch {
            AppLogger.viewModel.error("❌ Email verification failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
        AppLogger.viewModel.info("📊 Final state: isAuthenticated=\(self.isAuthenticated), needsEmailVerification=\(self.needsEmailVerification)")
    }

    func resendVerification() async {
        AppLogger.viewModel.info("📧 Resend verification initiated")
        isLoading = true
        errorMessage = nil

        do {
            _ = try await AuthService.shared.resendVerification()
            AppLogger.viewModel.info("✅ Verification email resent")
        } catch {
            AppLogger.viewModel.error("❌ Resend verification failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func updateNotificationSettings(notifyNewFeedback: Bool?, notifyNewComments: Bool?) async {
        AppLogger.viewModel.info("🔔 Updating notification settings - feedback: \(String(describing: notifyNewFeedback)), comments: \(String(describing: notifyNewComments))")

        do {
            let updatedUser = try await AdminAPIClient.shared.updateNotificationSettings(
                notifyNewFeedback: notifyNewFeedback,
                notifyNewComments: notifyNewComments
            )
            currentUser = updatedUser
            AppLogger.viewModel.info("✅ Notification settings updated")
        } catch {
            AppLogger.viewModel.error("❌ Failed to update notification settings: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }
    }

    // MARK: - Password Reset

    func requestPasswordReset() async {
        AppLogger.viewModel.info("🔑 Password reset request initiated for: \(self.resetEmail)")
        guard !resetEmail.isEmpty else {
            AppLogger.viewModel.warning("⚠️ Password reset validation failed - empty email")
            showError(message: "Please enter your email address")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await AuthService.shared.requestPasswordReset(email: resetEmail)
            resetEmailSent = true
            AppLogger.viewModel.info("✅ Password reset email sent")
        } catch {
            AppLogger.viewModel.error("❌ Password reset request failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    func resetPassword() async -> Bool {
        AppLogger.viewModel.info("🔄 Password reset initiated with code")
        guard resetCode.count == 8 else {
            AppLogger.viewModel.warning("⚠️ Invalid reset code length: \(self.resetCode.count)")
            showError(message: "Please enter the 8-character reset code")
            return false
        }

        guard resetNewPassword.count >= 8 else {
            AppLogger.viewModel.warning("⚠️ Password reset validation failed - password too short")
            showError(message: "Password must be at least 8 characters")
            return false
        }

        guard resetNewPassword == resetConfirmPassword else {
            AppLogger.viewModel.warning("⚠️ Password reset validation failed - passwords don't match")
            showError(message: "Passwords do not match")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await AuthService.shared.resetPassword(code: resetCode, newPassword: resetNewPassword)
            AppLogger.viewModel.info("✅ Password reset successful")
            clearResetState()
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Password reset failed: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func clearResetState() {
        AppLogger.viewModel.info("🧹 Clearing password reset state")
        resetEmail = ""
        resetCode = ""
        resetNewPassword = ""
        resetConfirmPassword = ""
        resetEmailSent = false
    }
}
