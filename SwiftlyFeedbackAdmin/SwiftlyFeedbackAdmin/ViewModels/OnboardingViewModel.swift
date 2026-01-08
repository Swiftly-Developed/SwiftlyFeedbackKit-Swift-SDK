import SwiftUI

@MainActor
@Observable
final class OnboardingViewModel {
    // MARK: - Onboarding State

    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case createAccount = 1
        case verifyEmail = 2
        case projectChoice = 3
        case createProject = 4
        case joinProject = 5
        case completion = 6

        var progress: Double {
            Double(rawValue) / Double(OnboardingStep.allCases.count - 1)
        }
    }

    enum ProjectSetupChoice {
        case create
        case join
    }

    var currentStep: OnboardingStep = .welcome
    var projectSetupChoice: ProjectSetupChoice?

    // MARK: - Account Creation Fields

    var signupName = ""
    var signupEmail = ""
    var signupPassword = ""
    var signupConfirmPassword = ""

    // MARK: - Email Verification

    var verificationCode = ""
    var resendCooldown = 0
    private var resendTimer: Timer?

    // MARK: - Project Creation Fields

    var newProjectName = ""
    var newProjectDescription = ""

    // MARK: - Join Project Fields

    var inviteCode = ""
    var invitePreview: InvitePreview?

    // MARK: - Created Project Result

    var createdProject: Project?
    var joinedProjectName: String?

    // MARK: - Loading and Error States

    var isLoading = false
    var errorMessage: String?
    var showError = false

    // MARK: - Dependencies

    private let authViewModel: AuthViewModel
    private let projectViewModel: ProjectViewModel

    init(authViewModel: AuthViewModel, projectViewModel: ProjectViewModel) {
        self.authViewModel = authViewModel
        self.projectViewModel = projectViewModel
        AppLogger.viewModel.info("OnboardingViewModel initialized")
    }

    func invalidateTimer() {
        resendTimer?.invalidate()
        resendTimer = nil
    }

    // MARK: - Navigation

    func goToNextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome:
                currentStep = .createAccount
            case .createAccount:
                currentStep = .verifyEmail
            case .verifyEmail:
                currentStep = .projectChoice
            case .projectChoice:
                if projectSetupChoice == .create {
                    currentStep = .createProject
                } else {
                    currentStep = .joinProject
                }
            case .createProject, .joinProject:
                currentStep = .completion
            case .completion:
                break // Handled by completing onboarding
            }
        }
        AppLogger.viewModel.info("Onboarding moved to step: \(self.currentStep)")
    }

    func goToPreviousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome:
                break
            case .createAccount:
                currentStep = .welcome
            case .verifyEmail:
                // Can't go back from email verification
                break
            case .projectChoice:
                // Can't go back to verification
                break
            case .createProject, .joinProject:
                currentStep = .projectChoice
                projectSetupChoice = nil
            case .completion:
                // Can't go back from completion
                break
            }
        }
        AppLogger.viewModel.info("Onboarding moved back to step: \(self.currentStep)")
    }

    var canGoBack: Bool {
        switch currentStep {
        case .welcome, .verifyEmail, .projectChoice, .completion:
            return false
        case .createAccount, .createProject, .joinProject:
            return true
        }
    }

    // MARK: - Account Creation

    var isSignupValid: Bool {
        !signupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !signupEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        signupPassword.count >= 8 &&
        signupPassword == signupConfirmPassword
    }

    func createAccount() async {
        AppLogger.viewModel.info("Onboarding: Creating account for \(self.signupEmail)")

        guard isSignupValid else {
            if signupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showError(message: "Please enter your name")
            } else if signupEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                showError(message: "Please enter your email")
            } else if signupPassword.count < 8 {
                showError(message: "Password must be at least 8 characters")
            } else if signupPassword != signupConfirmPassword {
                showError(message: "Passwords do not match")
            }
            return
        }

        isLoading = true
        errorMessage = nil

        // Use AuthViewModel for actual signup
        authViewModel.signupName = signupName
        authViewModel.signupEmail = signupEmail
        authViewModel.signupPassword = signupPassword
        authViewModel.signupConfirmPassword = signupConfirmPassword

        await authViewModel.signup()

        if authViewModel.showError {
            showError(message: authViewModel.errorMessage ?? "Failed to create account")
            authViewModel.showError = false
        } else if authViewModel.isAuthenticated {
            AppLogger.viewModel.info("Onboarding: Account created successfully")
            goToNextStep()
        }

        isLoading = false
    }

    // MARK: - Email Verification

    var isVerificationCodeValid: Bool {
        verificationCode.count == 8
    }

    func verifyEmail() async {
        AppLogger.viewModel.info("Onboarding: Verifying email with code \(self.verificationCode)")

        guard isVerificationCodeValid else {
            showError(message: "Please enter the 8-character verification code")
            return
        }

        isLoading = true
        errorMessage = nil

        authViewModel.verificationCode = verificationCode
        await authViewModel.verifyEmail()

        if authViewModel.showError {
            showError(message: authViewModel.errorMessage ?? "Invalid verification code")
            authViewModel.showError = false
        } else if authViewModel.currentUser?.isEmailVerified == true {
            AppLogger.viewModel.info("Onboarding: Email verified successfully")
            verificationCode = ""
            goToNextStep()
        }

        isLoading = false
    }

    func resendVerificationCode() async {
        AppLogger.viewModel.info("Onboarding: Resending verification code")

        isLoading = true
        await authViewModel.resendVerification()

        if authViewModel.showError {
            showError(message: authViewModel.errorMessage ?? "Failed to resend code")
            authViewModel.showError = false
        } else {
            startResendCooldown()
        }

        isLoading = false
    }

    private func startResendCooldown() {
        resendCooldown = 60
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.resendCooldown > 0 {
                    self.resendCooldown -= 1
                } else {
                    self.resendTimer?.invalidate()
                }
            }
        }
    }

    // MARK: - Project Choice

    func selectProjectChoice(_ choice: ProjectSetupChoice) {
        projectSetupChoice = choice
        goToNextStep()
    }

    // MARK: - Project Creation

    var isProjectNameValid: Bool {
        !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createProject() async {
        AppLogger.viewModel.info("Onboarding: Creating project \(self.newProjectName)")

        guard isProjectNameValid else {
            showError(message: "Please enter a project name")
            return
        }

        isLoading = true
        errorMessage = nil

        projectViewModel.newProjectName = newProjectName
        projectViewModel.newProjectDescription = newProjectDescription

        if await projectViewModel.createProject() {
            AppLogger.viewModel.info("Onboarding: Project created successfully")
            // Load the projects to get the newly created one
            await projectViewModel.loadProjects()

            // Load the full project details to get the API key
            if let firstProject = projectViewModel.projects.first {
                await projectViewModel.loadProject(id: firstProject.id)
                createdProject = projectViewModel.selectedProject
            }

            goToNextStep()
        } else if projectViewModel.showError {
            showError(message: projectViewModel.errorMessage ?? "Failed to create project")
            projectViewModel.showError = false
        }

        isLoading = false
    }

    // MARK: - Join Project

    var isInviteCodeValid: Bool {
        !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func previewInvite() async {
        AppLogger.viewModel.info("Onboarding: Previewing invite code \(self.inviteCode)")

        guard isInviteCodeValid else {
            showError(message: "Please enter an invite code")
            return
        }

        isLoading = true
        errorMessage = nil

        projectViewModel.inviteCode = inviteCode
        _ = await projectViewModel.previewInviteCode()

        if projectViewModel.showError {
            showError(message: projectViewModel.errorMessage ?? "Invalid invite code")
            projectViewModel.showError = false
        } else {
            invitePreview = projectViewModel.invitePreview
        }

        isLoading = false
    }

    func acceptInvite() async {
        AppLogger.viewModel.info("Onboarding: Accepting invite")

        guard invitePreview != nil else {
            showError(message: "Please verify the invite code first")
            return
        }

        isLoading = true
        errorMessage = nil

        if await projectViewModel.acceptInviteCode() {
            AppLogger.viewModel.info("Onboarding: Invite accepted successfully")
            joinedProjectName = invitePreview?.projectName
            await projectViewModel.loadProjects()
            goToNextStep()
        } else if projectViewModel.showError {
            showError(message: projectViewModel.errorMessage ?? "Failed to accept invite")
            projectViewModel.showError = false
        }

        isLoading = false
    }

    func clearInvitePreview() {
        invitePreview = nil
        projectViewModel.invitePreview = nil
    }

    // MARK: - Completion

    func completeOnboarding() {
        AppLogger.viewModel.info("Onboarding: Completing onboarding flow")
        OnboardingManager.shared.completeOnboarding()
    }

    // MARK: - Skip Project Setup (for users who want to explore first)

    func skipProjectSetup() {
        AppLogger.viewModel.info("Onboarding: Skipping project setup")
        currentStep = .completion
    }

    // MARK: - Error Handling

    private func showError(message: String) {
        AppLogger.viewModel.error("Onboarding error: \(message)")
        errorMessage = message
        showError = true
    }

    // MARK: - Logout During Onboarding

    func logout() async {
        AppLogger.viewModel.info("Onboarding: User logging out")
        await authViewModel.logout()

        // Reset onboarding state
        currentStep = .welcome
        signupName = ""
        signupEmail = ""
        signupPassword = ""
        signupConfirmPassword = ""
        verificationCode = ""
        newProjectName = ""
        newProjectDescription = ""
        inviteCode = ""
        invitePreview = nil
        createdProject = nil
        joinedProjectName = nil
        projectSetupChoice = nil
    }
}

// MARK: - Onboarding Manager

@MainActor
@Observable
final class OnboardingManager {
    static let shared = OnboardingManager()

    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    // Store as a tracked property so @Observable can detect changes
    // (computed properties reading from UserDefaults are not tracked)
    var hasCompletedOnboarding: Bool

    private init() {
        // Initialize from UserDefaults
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
        AppLogger.viewModel.info("OnboardingManager initialized - hasCompleted: \(self.hasCompletedOnboarding)")
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        AppLogger.viewModel.info("OnboardingManager: Onboarding marked as complete")
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
        AppLogger.viewModel.info("OnboardingManager: Onboarding reset")
    }
}
