import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    let onSwitchToSignup: () -> Void
    let onForgotPassword: () -> Void

    private enum LoginField: Hashable {
        case email, password
    }

    @FocusState private var focusedField: LoginField?
    @State private var appConfiguration = AppConfiguration.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                // FeedbackKit Logo
                FeedbackKitLogo(size: 80)

                Text("Feedback Kit")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Admin Dashboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Environment picker (only shown when multiple environments available)
                if AppEnvironment.availableEnvironments.count > 1 {
                    environmentPicker
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 20)

            // Form
            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.loginEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
                    .submitLabel(.next)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    #endif

                SecureField("Password", text: $viewModel.loginPassword)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit {
                        Task { await viewModel.login() }
                    }
                    .submitLabel(.go)

                HStack {
                    #if os(macOS)
                    Toggle("Keep me signed in", isOn: $viewModel.keepMeSignedIn)
                        .toggleStyle(.checkbox)
                        .font(.subheadline)
                    #else
                    Toggle("Keep me signed in", isOn: $viewModel.keepMeSignedIn)
                        .font(.subheadline)
                        .tint(.accentColor)
                    #endif
                    Spacer()
                    Button("Forgot Password?") {
                        onForgotPassword()
                    }
                    .font(.subheadline)
                }

                Button {
                    Task {
                        await viewModel.login()
                    }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Log In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading)
            }

            // Switch to signup
            HStack {
                Text("Don't have an account?")
                    .foregroundStyle(.secondary)
                Button("Sign Up") {
                    onSwitchToSignup()
                }
            }
            .font(.subheadline)
        }
        .padding(32)
        .frame(maxWidth: 400)
        .onAppear {
            focusedField = .email
        }
    }

    // MARK: - Environment Picker

    @ViewBuilder
    private var environmentPicker: some View {
        Menu {
            ForEach(appConfiguration.availableEnvironments, id: \.self) { env in
                Button {
                    appConfiguration.switchTo(env)
                } label: {
                    HStack {
                        Text(env.displayName)
                        if env == appConfiguration.environment {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(appConfiguration.environment.color)
                    .frame(width: 8, height: 8)
                Text(appConfiguration.environment.displayName)
                    .font(.caption)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
    }
}

// MARK: - FeedbackKit Logo

/// App logo using the FeedbackKit image asset
struct FeedbackKitLogo: View {
    let size: CGFloat

    var body: some View {
        Image("FeedbackKit")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel(), onSwitchToSignup: {}, onForgotPassword: {})
}

#Preview("FeedbackKit Logo") {
    VStack(spacing: 20) {
        FeedbackKitLogo(size: 40)
        FeedbackKitLogo(size: 60)
        FeedbackKitLogo(size: 80)
        FeedbackKitLogo(size: 120)
    }
    .padding()
}
