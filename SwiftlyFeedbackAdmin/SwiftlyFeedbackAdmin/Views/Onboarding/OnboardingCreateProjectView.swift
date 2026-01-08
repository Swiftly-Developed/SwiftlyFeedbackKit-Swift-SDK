import SwiftUI

struct OnboardingCreateProjectView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onBack: () -> Void

    private enum Field: Hashable {
        case name, description
    }

    @FocusState private var focusedField: Field?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: platformSpacing) {
                    Spacer(minLength: topSpacing(for: geometry))

                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: iconBackgroundSize, height: iconBackgroundSize)

                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: iconSize))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .accessibilityHidden(true)
                        }

                        VStack(spacing: 4) {
                            Text("Create Your Project")
                                .font(titleFont)
                                .fontWeight(.bold)
                                .accessibilityAddTraits(.isHeader)

                            Text("Set up a project to start collecting feedback from your users")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 8)

                    // Form Fields
                    #if os(macOS)
                    macOSFormFields
                    #else
                    iOSFormFields
                    #endif

                    // Info Card
                    OnboardingInfoCard(
                        icon: "key.fill",
                        iconColor: .orange,
                        title: "API Key",
                        description: "After creating your project, you'll receive an API key to integrate the SDK into your app."
                    )

                    Spacer(minLength: 20)

                    // Action Buttons
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                await viewModel.createProject()
                            }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: buttonMaxWidth)
                                    .frame(minHeight: 44)
                            } else {
                                Text("Create Project")
                                    .font(.headline)
                                    .frame(maxWidth: buttonMaxWidth)
                                    .frame(minHeight: 44)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!viewModel.isProjectNameValid || viewModel.isLoading)
                        .accessibilityHint(viewModel.isProjectNameValid ? "Create your new project" : "Enter a project name to continue")

                        Button {
                            onBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundStyle(.secondary)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline)
                        .accessibilityLabel("Go back to project choice")
                    }
                    .padding(.bottom, bottomPadding)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(maxWidth: maxContentWidth)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            #if os(iOS)
            focusedField = .name
            #endif
        }
    }

    // MARK: - iOS Form Fields

    #if os(iOS)
    private var iOSFormFields: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Project Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("My Awesome App", text: $viewModel.newProjectName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .description
                    }
                    .accessibilityLabel("Project name")
                    .accessibilityHint("Enter the name for your new project")

                Text("This is how your project will appear to your team")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text("(Optional)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                TextField("A brief description of your project", text: $viewModel.newProjectDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .description)
                    .lineLimit(3...6)
                    .submitLabel(.done)
                    .onSubmit {
                        if viewModel.isProjectNameValid {
                            Task { await viewModel.createProject() }
                        }
                    }
                    .accessibilityLabel("Project description, optional")
                    .accessibilityHint("Enter a brief description to help your team understand what this project is for")

                Text("Help your team understand what this project is for")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif

    // MARK: - macOS Form Fields

    #if os(macOS)
    private var macOSFormFields: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Project Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("My Awesome App", text: $viewModel.newProjectName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = .description
                    }

                Text("This is how your project will appear to your team")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Description")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    Text("(Optional)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                TextField("A brief description of your project", text: $viewModel.newProjectDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .description)
                    .lineLimit(3...6)

                Text("Help your team understand what this project is for")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif

    // MARK: - Platform-Adaptive Properties

    private var isCompactWidth: Bool {
        #if os(iOS)
        return horizontalSizeClass == .compact
        #else
        return false
        #endif
    }

    private var iconBackgroundSize: CGFloat {
        #if os(macOS)
        return 80
        #else
        return isCompactWidth ? 80 : 100
        #endif
    }

    private var iconSize: CGFloat {
        #if os(macOS)
        return 36
        #else
        return isCompactWidth ? 36 : 44
        #endif
    }

    private var titleFont: Font {
        #if os(macOS)
        return .title
        #else
        return isCompactWidth ? .title2 : .title
        #endif
    }

    private var platformSpacing: CGFloat {
        #if os(macOS)
        return 24
        #else
        return isCompactWidth ? 20 : 24
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
        return 420
        #else
        return isCompactWidth ? .infinity : 480
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
        return max(16, geometry.size.height * 0.03)
        #else
        if isCompactWidth {
            return 16
        } else {
            return max(32, geometry.size.height * 0.05)
        }
        #endif
    }
}

// MARK: - Info Card Component

private struct OnboardingInfoCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(iconColor, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

#Preview("iPhone") {
    OnboardingCreateProjectView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onBack: {}
    )
}

#Preview("iPad") {
    OnboardingCreateProjectView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onBack: {}
    )
    .previewDevice("iPad Pro (11-inch)")
}
