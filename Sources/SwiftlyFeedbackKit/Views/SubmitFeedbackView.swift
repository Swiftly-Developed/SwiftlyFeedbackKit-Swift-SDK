import SwiftUI

public struct SubmitFeedbackView: View {
    let swiftlyFeedback: SwiftlyFeedback?
    let onDismiss: () -> Void

    @State private var viewModel = SubmitFeedbackViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private enum Field: Hashable {
        case title, description, email
    }

    public init(swiftlyFeedback: SwiftlyFeedback? = nil, onDismiss: @escaping () -> Void = {}) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasInvalidApiKey {
                    InvalidApiKeyView()
                } else {
                    formContent
                }
            }
            .navigationTitle(String(localized: Strings.submitFeedbackTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: Strings.cancelButton)) {
                        dismiss()
                        onDismiss()
                    }
                }
                if !viewModel.hasInvalidApiKey {
                    ToolbarItem(placement: .confirmationAction) {
                        submitButton
                    }
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
            .onAppear {
                if SwiftlyFeedback.config.enableAutomaticViewTracking {
                    SwiftlyFeedback.view(.submitFeedback)
                }
            }
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 350)
            #endif
        }
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        #if os(macOS)
        macOSForm
        #else
        iOSForm
        #endif
    }

    // MARK: - iOS/iPadOS Form

    #if !os(macOS)
    private var iOSForm: some View {
        Form {
            Section {
                TextField(String(localized: Strings.formTitle), text: $viewModel.title)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .description }

                Picker(String(localized: Strings.formCategory), selection: $viewModel.category) {
                    ForEach(FeedbackCategory.allCases, id: \.self) { category in
                        Label(category.displayName, systemImage: category.iconName)
                            .tag(category)
                    }
                }
            }

            Section(String(localized: Strings.formDescription)) {
                TextEditor(text: $viewModel.description)
                    .focused($focusedField, equals: .description)
                    .frame(minHeight: 120)
            }

            if config.showEmailField {
                Section {
                    TextField(String(localized: Strings.formEmailPlaceholder), text: $viewModel.email)
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { submitIfValid() }
                } header: {
                    Text(Strings.formEmail)
                } footer: {
                    Text("Optional - for follow-up questions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
    #endif

    // MARK: - macOS Form

    #if os(macOS)
    private var macOSForm: some View {
        VStack(spacing: 0) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow {
                    Text("Title:")
                        .gridColumnAlignment(.trailing)
                    TextField(String(localized: Strings.formTitlePlaceholder), text: $viewModel.title)
                        .focused($focusedField, equals: .title)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { focusedField = .description }
                }

                GridRow {
                    Text("Category:")
                    Picker("", selection: $viewModel.category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                GridRow(alignment: .top) {
                    Text("Description:")
                    TextEditor(text: $viewModel.description)
                        .focused($focusedField, equals: .description)
                        .font(.body)
                        .frame(minHeight: 120, maxHeight: 200)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                }

                if config.showEmailField {
                    GridRow {
                        Text("Email:")
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(String(localized: Strings.formEmailPlaceholder), text: $viewModel.email)
                                .focused($focusedField, equals: .email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .onSubmit { submitIfValid() }
                            Text("Optional - for follow-up questions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(20)

            Spacer()
        }
    }
    #endif

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            submitIfValid()
        } label: {
            #if os(macOS)
            Text(Strings.submitButton)
            #else
            if viewModel.isSubmitting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(Strings.submitButton)
            }
            #endif
        }
        .tint(theme.primaryColor.resolve(for: colorScheme))
        .disabled(!viewModel.isValid || viewModel.isSubmitting)
        #if os(macOS)
        .keyboardShortcut(.return, modifiers: .command)
        #endif
    }

    // MARK: - Actions

    private func submitIfValid() {
        guard viewModel.isValid, !viewModel.isSubmitting else { return }
        Task {
            await viewModel.submit(using: swiftlyFeedback)
            if viewModel.isSubmitted {
                dismiss()
                onDismiss()
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
    var hasInvalidApiKey = false

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit(using swiftlyFeedback: SwiftlyFeedback?) async {
        guard let sf = swiftlyFeedback, isValid else { return }
        guard !hasInvalidApiKey else { return }

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
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: Strings.errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
