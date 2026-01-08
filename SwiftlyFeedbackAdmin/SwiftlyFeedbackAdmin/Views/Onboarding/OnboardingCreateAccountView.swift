import SwiftUI

struct OnboardingCreateAccountView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onBack: () -> Void

    private enum Field: Hashable {
        case name, email, password, confirmPassword
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

                            Image(systemName: "person.badge.plus")
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
                            Text("Create Your Account")
                                .font(titleFont)
                                .fontWeight(.bold)
                                .accessibilityAddTraits(.isHeader)

                            Text("Join thousands of developers collecting feedback")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.bottom, 8)

                    // Form Fields - Use Form on macOS for native styling
                    #if os(macOS)
                    macOSFormFields
                    #else
                    iOSFormFields
                    #endif

                    // Password Strength Indicator
                    if !viewModel.signupPassword.isEmpty {
                        PasswordStrengthView(password: viewModel.signupPassword)
                            .padding(.horizontal, isCompactWidth ? 0 : 16)
                    }

                    Spacer(minLength: 20)

                    // Action Buttons
                    VStack(spacing: 16) {
                        Button {
                            Task {
                                await viewModel.createAccount()
                            }
                        } label: {
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: buttonMaxWidth)
                                    .frame(minHeight: 44)
                            } else {
                                Text("Create Account")
                                    .font(.headline)
                                    .frame(maxWidth: buttonMaxWidth)
                                    .frame(minHeight: 44)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(!viewModel.isSignupValid || viewModel.isLoading)
                        .accessibilityHint(viewModel.isSignupValid ? "Create your account" : "Fill in all fields to continue")

                        Button {
                            onBack()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .accessibilityLabel("Go back to welcome screen")
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
        VStack(spacing: 16) {
            OnboardingTextField(
                label: "Name",
                placeholder: "Your name",
                text: $viewModel.signupName,
                contentType: .name,
                keyboardType: .default,
                autocapitalization: .words,
                isFocused: focusedField == .name,
                onFocus: { focusedField = .name },
                onSubmit: { focusedField = .email },
                submitLabel: .next
            )
            .focused($focusedField, equals: .name)

            OnboardingTextField(
                label: "Email",
                placeholder: "your@email.com",
                text: $viewModel.signupEmail,
                contentType: .emailAddress,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                isFocused: focusedField == .email,
                onFocus: { focusedField = .email },
                onSubmit: { focusedField = .password },
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)

            OnboardingSecureField(
                label: "Password",
                placeholder: "At least 8 characters",
                text: $viewModel.signupPassword,
                errorMessage: viewModel.signupPassword.isEmpty || viewModel.signupPassword.count >= 8
                    ? nil : "Password must be at least 8 characters",
                isFocused: focusedField == .password,
                onFocus: { focusedField = .password },
                onSubmit: { focusedField = .confirmPassword },
                submitLabel: .next
            )
            .focused($focusedField, equals: .password)

            OnboardingSecureField(
                label: "Confirm Password",
                placeholder: "Re-enter your password",
                text: $viewModel.signupConfirmPassword,
                errorMessage: viewModel.signupConfirmPassword.isEmpty || viewModel.signupPassword == viewModel.signupConfirmPassword
                    ? nil : "Passwords do not match",
                isFocused: focusedField == .confirmPassword,
                onFocus: { focusedField = .confirmPassword },
                onSubmit: {
                    if viewModel.isSignupValid {
                        Task { await viewModel.createAccount() }
                    }
                },
                submitLabel: .go
            )
            .focused($focusedField, equals: .confirmPassword)
        }
    }
    #endif

    // MARK: - macOS Form Fields

    #if os(macOS)
    private var macOSFormFields: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("Your name", text: $viewModel.signupName)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.name)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("your@email.com", text: $viewModel.signupEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                SecureField("At least 8 characters", text: $viewModel.signupPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                if !viewModel.signupPassword.isEmpty && viewModel.signupPassword.count < 8 {
                    ValidationMessage(text: "Password must be at least 8 characters", type: .warning)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm Password")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                SecureField("Re-enter your password", text: $viewModel.signupConfirmPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.newPassword)

                if !viewModel.signupConfirmPassword.isEmpty &&
                    viewModel.signupPassword != viewModel.signupConfirmPassword {
                    ValidationMessage(text: "Passwords do not match", type: .error)
                }
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

// MARK: - Reusable Form Components

#if os(iOS)
private struct OnboardingTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isFocused: Bool = false
    var onFocus: () -> Void = {}
    var onSubmit: () -> Void = {}
    var submitLabel: SubmitLabel = .next

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(autocapitalization)
                .onSubmit(onSubmit)
                .submitLabel(submitLabel)
                .accessibilityLabel(label)
        }
    }
}

private struct OnboardingSecureField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var errorMessage: String?
    var isFocused: Bool = false
    var onFocus: () -> Void = {}
    var onSubmit: () -> Void = {}
    var submitLabel: SubmitLabel = .next

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                .onSubmit(onSubmit)
                .submitLabel(submitLabel)
                .accessibilityLabel(label)

            if let error = errorMessage {
                ValidationMessage(text: error, type: .warning)
            }
        }
    }
}
#endif

private struct ValidationMessage: View {
    enum MessageType {
        case warning, error
    }

    let text: String
    let type: MessageType

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(type == .error ? .red : .orange)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type == .error ? "Error" : "Warning"): \(text)")
    }
}

private struct PasswordStrengthView: View {
    let password: String

    private var strength: (level: Int, text: String, color: Color) {
        var score = 0

        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.contains(where: { $0.isUppercase }) { score += 1 }
        if password.contains(where: { $0.isNumber }) { score += 1 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) { score += 1 }

        switch score {
        case 0...1:
            return (1, "Weak", .red)
        case 2...3:
            return (2, "Medium", .orange)
        case 4:
            return (3, "Strong", .green)
        default:
            return (4, "Very Strong", .green)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < strength.level ? strength.color : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                }
            }

            HStack {
                Text("Password strength:")
                    .foregroundStyle(.secondary)
                Text(strength.text)
                    .foregroundStyle(strength.color)
                    .fontWeight(.medium)
            }
            .font(.caption)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Password strength: \(strength.text)")
    }
}

#Preview("iPhone") {
    OnboardingCreateAccountView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onBack: {}
    )
}

#Preview("iPad") {
    OnboardingCreateAccountView(
        viewModel: OnboardingViewModel(
            authViewModel: AuthViewModel(),
            projectViewModel: ProjectViewModel()
        ),
        onBack: {}
    )
    .previewDevice("iPad Pro (11-inch)")
}
