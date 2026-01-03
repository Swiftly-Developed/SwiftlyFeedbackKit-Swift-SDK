import SwiftUI

public struct SubmitFeedbackView: View {
    let swiftlyFeedback: SwiftlyFeedback?
    let onDismiss: () -> Void

    @State private var viewModel = SubmitFeedbackViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    public init(swiftlyFeedback: SwiftlyFeedback? = nil, onDismiss: @escaping () -> Void = {}) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: Strings.formTitle), text: $viewModel.title)

                    Picker(String(localized: Strings.formCategory), selection: $viewModel.category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section(String(localized: Strings.formDescription)) {
                    TextEditor(text: $viewModel.description)
                        .frame(minHeight: 100)
                }

                if config.showEmailField {
                    Section {
                        TextField(String(localized: Strings.formEmailPlaceholder), text: $viewModel.email)
                            .textContentType(.emailAddress)
                            #if !os(macOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif
                    } header: {
                        Text(Strings.formEmail)
                    }
                }
            }
            .navigationTitle(String(localized: Strings.submitFeedbackTitle))
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: Strings.cancelButton)) {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: Strings.submitButton)) {
                        Task {
                            await viewModel.submit(using: swiftlyFeedback)
                            if viewModel.isSubmitted {
                                dismiss()
                                onDismiss()
                            }
                        }
                    }
                    .tint(theme.primaryColor.resolve(for: colorScheme))
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .alert(String(localized: Strings.errorTitle), isPresented: $viewModel.showingError) {
                Button(String(localized: Strings.errorOK), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? String(localized: Strings.errorGeneric))
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }
}

@MainActor
@Observable
final class SubmitFeedbackViewModel {
    var title = ""
    var description = ""
    var category: FeedbackCategory = .featureRequest
    var email = ""
    var isSubmitting = false
    var isSubmitted = false
    var showingError = false
    var errorMessage: String?

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit(using swiftlyFeedback: SwiftlyFeedback?) async {
        guard let sf = swiftlyFeedback, isValid else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await sf.submitFeedback(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                email: email.isEmpty ? nil : email
            )
            isSubmitted = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
