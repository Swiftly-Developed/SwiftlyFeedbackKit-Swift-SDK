import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    let onSwitchToSignup: () -> Void
    let onForgotPassword: () -> Void

    private enum LoginField: Hashable {
        case email, password
    }

    @FocusState private var focusedField: LoginField?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Feedback Kit")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Admin Dashboard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
}

#Preview {
    LoginView(viewModel: AuthViewModel(), onSwitchToSignup: {}, onForgotPassword: {})
}
