import SwiftUI

struct RootView: View {
    @State private var authViewModel = AuthViewModel()
    @State private var projectViewModel = ProjectViewModel()
    @State private var onboardingManager = OnboardingManager.shared

    var body: some View {
        Group {
            if authViewModel.isCheckingAuthState {
                // Show loading while checking auth state (including auto re-login)
                ProgressView("Signing in...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authViewModel.isAuthenticated {
                if authViewModel.needsEmailVerification {
                    // User is authenticated but needs email verification
                    // This handles returning users who haven't verified yet
                    EmailVerificationView(viewModel: authViewModel)
                } else if !onboardingManager.hasCompletedOnboarding {
                    // User is authenticated and verified but hasn't completed onboarding
                    // Show project choice and completion steps
                    OnboardingPostAuthView(
                        authViewModel: authViewModel,
                        projectViewModel: projectViewModel
                    )
                } else {
                    // Fully authenticated and onboarded user
                    MainTabView(authViewModel: authViewModel)
                }
            } else {
                // Not authenticated - show onboarding or login
                if !onboardingManager.hasCompletedOnboarding {
                    OnboardingContainerView(
                        authViewModel: authViewModel,
                        projectViewModel: projectViewModel
                    )
                } else {
                    // Returning user who has completed onboarding before
                    AuthContainerView(viewModel: authViewModel)
                }
            }
        }
        .animation(.default, value: authViewModel.isCheckingAuthState)
        .animation(.default, value: authViewModel.isAuthenticated)
        .animation(.default, value: authViewModel.needsEmailVerification)
        .animation(.default, value: onboardingManager.hasCompletedOnboarding)
        .task {
            // Initialize AdminAPIClient with the correct baseURL from AppConfiguration
            await AdminAPIClient.shared.initializeBaseURL()
        }
        .onReceive(NotificationCenter.default.publisher(for: .environmentDidChange)) { notification in
            // Environment changed - tokens are environment-specific, so log out the user
            guard let newEnvironment = notification.object as? AppEnvironment else { return }
            AppLogger.viewModel.info("🔄 Environment changed to \(newEnvironment.displayName) - logging out user")

            // Clear auth token (environment-specific) - use SecureStorageManager
            SecureStorageManager.shared.authToken = nil

            // Force logout to reset auth state
            authViewModel.forceLogout()

            // Clear project cache
            projectViewModel.clearCache()
        }
    }
}

/// View shown to authenticated users who haven't completed the project setup part of onboarding
struct OnboardingPostAuthView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var projectViewModel: ProjectViewModel
    @State private var onboardingViewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let viewModel = onboardingViewModel {
                postAuthContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .onAppear {
                        let vm = OnboardingViewModel(
                            authViewModel: authViewModel,
                            projectViewModel: projectViewModel
                        )
                        // Start at project choice since user is already authenticated
                        vm.currentStep = .projectChoice
                        onboardingViewModel = vm
                    }
            }
        }
    }

    @ViewBuilder
    private func postAuthContent(viewModel: OnboardingViewModel) -> some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress Bar
                OnboardingProgressBar(progress: viewModel.currentStep.progress)
                    .padding(.horizontal, 32)
                    .padding(.top, 16)

                // Content
                Group {
                    switch viewModel.currentStep {
                    case .welcome1, .welcome2, .welcome3, .createAccount, .verifyEmail, .paywall:
                        // These shouldn't happen in post-auth flow, redirect to project choice
                        OnboardingProjectChoiceView(
                            viewModel: viewModel,
                            userName: authViewModel.currentUser?.name
                        )
                        .onAppear {
                            viewModel.currentStep = .projectChoice
                        }

                    case .projectChoice:
                        OnboardingProjectChoiceView(
                            viewModel: viewModel,
                            userName: authViewModel.currentUser?.name
                        )

                    case .createProject:
                        OnboardingCreateProjectView(
                            viewModel: viewModel,
                            onBack: {
                                viewModel.goToPreviousStep()
                            }
                        )

                    case .joinProject:
                        OnboardingJoinProjectView(
                            viewModel: viewModel,
                            onBack: {
                                viewModel.goToPreviousStep()
                            }
                        )

                    case .completion:
                        OnboardingCompletionView(
                            viewModel: viewModel,
                            onComplete: {
                                // Onboarding complete - RootView will handle navigation
                            }
                        )
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .alert("Error", isPresented: Bindable(viewModel).showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }

    private var backgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}

private struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 8)

            Text("\(Int(progress * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RootView()
}
