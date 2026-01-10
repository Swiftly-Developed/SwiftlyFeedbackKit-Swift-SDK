import SwiftUI

struct OnboardingCompletionView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @State private var animateCheckmark = false
    @State private var animateContent = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: platformSpacing) {
                    Spacer(minLength: topSpacing(for: geometry))

                    // Success Animation
                    ZStack {
                        // Animated rings
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.green.opacity(0.4), .blue.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(
                                    width: checkmarkSize + CGFloat(index * 30),
                                    height: checkmarkSize + CGFloat(index * 30)
                                )
                                .opacity(animateCheckmark ? 0.5 - Double(index) * 0.15 : 0)
                                .scaleEffect(animateCheckmark ? 1 : 0.5)
                        }

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: checkmarkSize, height: checkmarkSize)
                            .scaleEffect(animateCheckmark ? 1 : 0)
                            .shadow(color: .green.opacity(0.3), radius: 20, x: 0, y: 10)

                        Image(systemName: "checkmark")
                            .font(.system(size: checkmarkIconSize, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(animateCheckmark ? 1 : 0)
                            .scaleEffect(animateCheckmark ? 1 : 0.5)
                            .accessibilityHidden(true)
                    }
                    .frame(height: checkmarkSize + 60)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Success")

                    // Content
                    VStack(spacing: 16) {
                        Text("You're All Set!")
                            .font(titleFont)
                            .fontWeight(.bold)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                            .accessibilityAddTraits(.isHeader)

                        Text(completionMessage)
                            .font(subtitleFont)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .opacity(animateContent ? 1 : 0)
                            .offset(y: animateContent ? 0 : 20)
                    }

                    // Project Summary (if created/joined)
                    if let project = viewModel.createdProject {
                        ProjectSummaryCard(
                            title: "Project Created",
                            projectName: project.name,
                            apiKey: project.apiKey,
                            icon: "folder.fill",
                            iconColor: .blue,
                            isCompact: isCompactWidth
                        )
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    } else if let projectName = viewModel.joinedProjectName {
                        ProjectSummaryCard(
                            title: "Joined Project",
                            projectName: projectName,
                            apiKey: nil,
                            icon: "person.2.fill",
                            iconColor: .purple,
                            isCompact: isCompactWidth
                        )
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                    }

                    // Next Steps
                    NextStepsSection(isCompact: isCompactWidth)
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.3), value: animateContent)

                    // Environment Note (for non-production environments)
                    if AppConfiguration.currentEnvironment != .production {
                        EnvironmentNoteSection(
                            environment: AppConfiguration.currentEnvironment,
                            isCompact: isCompactWidth
                        )
                        .opacity(animateContent ? 1 : 0)
                        .offset(y: animateContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.4), value: animateContent)
                    }

                    Spacer(minLength: 20)

                    // Get Started Button
                    Button {
                        viewModel.completeOnboarding()
                        onComplete()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: buttonMaxWidth)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.bottom, bottomPadding)
                    .accessibilityHint("Complete onboarding and start using Feedback Kit")
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animateCheckmark = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateContent = true
                }
            }
        }
    }

    private var completionMessage: String {
        if viewModel.createdProject != nil {
            return "Your project is ready. Start collecting feedback from your users today."
        } else if viewModel.joinedProjectName != nil {
            return "You've joined the team. Start collaborating on feedback right away."
        } else {
            return "You can create or join a project anytime from the Projects tab."
        }
    }

    // MARK: - Platform-Adaptive Properties

    private var isCompactWidth: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    private var checkmarkSize: CGFloat {
        #if os(macOS)
        return 100
        #else
        return isCompactWidth ? 100 : 120
        #endif
    }

    private var checkmarkIconSize: CGFloat {
        #if os(macOS)
        return 44
        #else
        return isCompactWidth ? 44 : 52
        #endif
    }

    private var titleFont: Font {
        #if os(macOS)
        return .largeTitle
        #else
        return isCompactWidth ? .title : .largeTitle
        #endif
    }

    private var subtitleFont: Font {
        #if os(macOS)
        return .title3
        #else
        return isCompactWidth ? .body : .title3
        #endif
    }

    private var platformSpacing: CGFloat {
        #if os(macOS)
        return 28
        #else
        return isCompactWidth ? 24 : 32
        #endif
    }

    private var horizontalPadding: CGFloat {
        #if os(macOS)
        return 40
        #else
        return isCompactWidth ? 24 : 40
        #endif
    }

    private var maxContentWidth: CGFloat {
        #if os(macOS)
        return 520
        #else
        return isCompactWidth ? .infinity : 600
        #endif
    }

    private var buttonMaxWidth: CGFloat {
        #if os(macOS)
        return 280
        #else
        return isCompactWidth ? .infinity : 320
        #endif
    }

    private var bottomPadding: CGFloat {
        #if os(macOS)
        return 32
        #else
        return isCompactWidth ? 16 : 32
        #endif
    }

    private func topSpacing(for geometry: GeometryProxy) -> CGFloat {
        #if os(macOS)
        return max(20, geometry.size.height * 0.05)
        #else
        if isCompactWidth {
            return 20
        } else {
            return max(40, geometry.size.height * 0.08)
        }
        #endif
    }
}

// MARK: - Project Summary Card

private struct ProjectSummaryCard: View {
    let title: String
    let projectName: String
    let apiKey: String?
    let icon: String
    let iconColor: Color
    let isCompact: Bool

    @State private var copiedKey = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)

            Divider()

            HStack {
                Text("Project")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(projectName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Project: \(projectName)")

            if let apiKey = apiKey {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("API Key")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            copyToClipboard(apiKey)
                            copiedKey = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedKey = false
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: copiedKey ? "checkmark" : "doc.on.doc")
                                Text(copiedKey ? "Copied!" : "Copy")
                            }
                            .font(.caption)
                            .frame(minHeight: 32) // Touch-friendly on iOS
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel(copiedKey ? "API key copied" : "Copy API key")
                    }

                    Text(apiKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(isCompact ? 10 : 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("API key: \(apiKey)")
                }
            }
        }
        .padding(isCompact ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var backgroundFill: some ShapeStyle {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    private func copyToClipboard(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

// MARK: - Next Steps Section

private struct NextStepsSection: View {
    let isCompact: Bool

    private let steps: [(icon: String, title: String, description: String)] = [
        ("swift", "Integrate the SDK", "Add SwiftlyFeedbackKit to your app"),
        ("bubble.left.and.bubble.right", "Collect Feedback", "Users can submit feature requests and bug reports"),
        ("chart.bar.xaxis", "Analyze & Prioritize", "Use insights to build what matters most")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's Next?")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: isCompact ? 12 : 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)

                            Text("\(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text(step.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(index + 1): \(step.title). \(step.description)")
                }
            }
        }
        .padding(isCompact ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}

// MARK: - Environment Note Section

/// Shows important notes about the current environment (DEV/TestFlight)
private struct EnvironmentNoteSection: View {
    let environment: AppEnvironment
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(environment.color)
                    .frame(width: 8, height: 8)
                Text("\(environment.displayName) Environment")
                    .font(.headline)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(environment.displayName) environment active")

            VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
                // All features unlocked
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("All Features Unlocked")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Pro and Team features are enabled for testing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)

                // Data retention warning
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 20)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("7-Day Data Retention")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Test data is automatically deleted after 7 days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(isCompact ? 16 : 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(environment.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(environment.color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview("iPhone") {
    OnboardingCompletionView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onComplete: {}
    )
}

#Preview("iPad") {
    OnboardingCompletionView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onComplete: {}
    )
}
