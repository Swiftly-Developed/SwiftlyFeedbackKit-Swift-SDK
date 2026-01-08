import SwiftUI

struct OnboardingContainerView: View {
    @Bindable var authViewModel: AuthViewModel
    @Bindable var projectViewModel: ProjectViewModel
    @State private var onboardingViewModel: OnboardingViewModel?

    // Track if we're showing login flow instead of onboarding
    @State private var showLoginFlow = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if showLoginFlow {
                // Standard login flow for existing users
                AuthContainerView(viewModel: authViewModel)
            } else if let viewModel = onboardingViewModel {
                // Onboarding flow for new users
                onboardingContent(viewModel: viewModel)
            } else {
                // Loading state
                ProgressView()
                    .onAppear {
                        onboardingViewModel = OnboardingViewModel(
                            authViewModel: authViewModel,
                            projectViewModel: projectViewModel
                        )
                    }
                    .accessibilityLabel("Loading onboarding")
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showLoginFlow)
    }

    @ViewBuilder
    private func onboardingContent(viewModel: OnboardingViewModel) -> some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress Bar (shown after welcome screen)
                if viewModel.currentStep != .welcome {
                    OnboardingProgressBar(
                        progress: viewModel.currentStep.progress,
                        isCompact: isCompactWidth
                    )
                    .padding(.horizontal, progressBarPadding)
                    .padding(.top, 16)
                    .transition(.opacity)
                }

                // Content
                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        OnboardingWelcomeView(
                            onContinue: {
                                viewModel.goToNextStep()
                            },
                            onLogin: {
                                showLoginFlow = true
                            }
                        )

                    case .createAccount:
                        OnboardingCreateAccountView(
                            viewModel: viewModel,
                            onBack: {
                                viewModel.goToPreviousStep()
                            }
                        )

                    case .verifyEmail:
                        OnboardingVerifyEmailView(
                            viewModel: viewModel,
                            userEmail: authViewModel.currentUser?.email,
                            onLogout: {
                                Task {
                                    await viewModel.logout()
                                }
                            }
                        )

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

    // MARK: - Platform-Adaptive Properties

    private var isCompactWidth: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    private var progressBarPadding: CGFloat {
        #if os(macOS)
        return 80
        #else
        return isCompactWidth ? 24 : 80
        #endif
    }

    private var backgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}

// MARK: - Progress Bar Component

private struct OnboardingProgressBar: View {
    let progress: Double
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: barHeight)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: barHeight)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: barHeight)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Progress: \(Int(progress * 100)) percent complete")
            .accessibilityValue("\(Int(progress * 100)) percent")

            // Progress text
            Text("\(Int(progress * 100))% complete")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    private var barHeight: CGFloat {
        isCompact ? 6 : 8
    }
}

#Preview("Welcome") {
    OnboardingContainerView(
        authViewModel: AuthViewModel(),
        projectViewModel: ProjectViewModel()
    )
}

#Preview("Welcome - iPad") {
    OnboardingContainerView(
        authViewModel: AuthViewModel(),
        projectViewModel: ProjectViewModel()
    )
    .previewDevice("iPad Pro (11-inch)")
}
