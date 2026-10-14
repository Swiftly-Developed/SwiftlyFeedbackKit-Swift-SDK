import SwiftUI

public struct SubmitFeedbackView: View {
    let swiftlyFeedback: SwiftlyFeedback?
    let onDismiss: () -> Void

    @State private var viewModel = SubmitFeedbackViewModel()
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    private enum Field: Hashable {
        case title, description, email
    }

    public init(swiftlyFeedback: SwiftlyFeedback? = nil, onDismiss: @escaping () -> Void = {}) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.current
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
            .navigationTitle(String(localized: .feedbackSubmitTitle))
            .tint(theme.primaryColor == .default ? Color.primary : theme.primaryColor.resolve(for: colorScheme))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) {
                        dismiss()
                        onDismiss()
                    } label: {
                        Text(String(localized: .buttonCancel))
                            .font(.body)
                    }
                }
                if !viewModel.hasInvalidApiKey {
                    ToolbarItem(placement: .confirmationAction) {
                        submitButton
                    }
                }
            }
            #endif
            .alert(String(localized: .errorTitle), isPresented: $viewModel.showingError) {
                Button(String(localized: .errorOk), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? String(localized: .errorGeneric))
            }
            .overlay {
                if viewModel.isSubmitting {
                    // S1: action progress (submit in flight), not a content load — the spinner is the mandated treatment.
                    ProgressView()
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(.rect(cornerRadius: 12))
                        .accessibilityLabel(String(localized: .accessibilitySubmitting))
                }
            }
            .onAppear {
                if SwiftlyFeedback.configuration.enableAutomaticViewTracking {
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
        formFields
            .safeAreaInset(edge: .bottom) {
                if !viewModel.hasInvalidApiKey {
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: submitIfValid) {
                            Text(String(localized: .buttonSubmit))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        Button(role: .cancel) {
                            dismiss()
                            onDismiss()
                        } label: {
                            Text(String(localized: .buttonCancel))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding()
                    .disabled(viewModel.isSubmitting)
                }
            }
    }

    private var formFields: some View {
        Form {
            Section {
                TextField(String(localized: .feedbackFormTitle), text: $viewModel.title)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .description }
                    .accessibilityHint(String(localized: .accessibilityFormRequired))

                LabeledContent(String(localized: .feedbackFormCategory)) {
                    Menu {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Button(category.localizedDisplayName) {
                                viewModel.category = category
                            }
                        }
                    } label: {
                        Text(viewModel.category.localizedDisplayName)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .disabled(viewModel.isSubmitting)

            Section {
                Text(String(localized: .feedbackFormDescription))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField(
                    String(localized: .feedbackFormDescription),
                    text: $viewModel.description,
                    axis: .vertical
                )
                .focused($focusedField, equals: .description)
                .lineLimit(3...8)
                .accessibilityLabel(String(localized: .feedbackFormDescription))
                .accessibilityHint(String(localized: .accessibilityFormDescriptionHint))
                if let unmetRequirement = viewModel.unmetRequirement {
                    Text(unmetRequirement)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .disabled(viewModel.isSubmitting)

            if config.showEmailField {
                Section {
                    TextField(String(localized: .feedbackFormEmail), text: $viewModel.email)
                        .focused($focusedField, equals: .email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { submitIfValid() }
                        .accessibilityHint(String(localized: .feedbackFormEmailPlaceholder))

                    if config.showMailingListOptIn && !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Toggle(String(localized: .mailingListOptIn), isOn: $viewModel.subscribeToMailingList)

                        if viewModel.subscribeToMailingList {
                            Toggle(String(localized: .mailingListOperational), isOn: $viewModel.operationalEmails)
                            Toggle(String(localized: .mailingListMarketing), isOn: $viewModel.marketingEmails)
                        }
                    }
                }
                .disabled(viewModel.isSubmitting)
            }
        }
        // `scrollDismissesKeyboard` is iOS-family-only and unavailable on
        // visionOS, which also compiles this `#if !os(macOS)` block.
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
    }
    #endif

    // MARK: - macOS Form

    #if os(macOS)
    private var macOSForm: some View {
        ScrollView {
            VStack(alignment: .leading) {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 16) {
                GridRow {
                    Text(String(localized: .feedbackFormTitle))
                        .gridColumnAlignment(.trailing)
                    TextField(String(localized: .feedbackFormTitlePlaceholder), text: $viewModel.title)
                        .focused($focusedField, equals: .title)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { focusedField = .description }
                        .accessibilityLabel(String(localized: .feedbackFormTitle))
                        .accessibilityHint(String(localized: .accessibilityFormRequired))
                }

                GridRow {
                    Text(String(localized: .feedbackFormCategory))
                    Picker(String(localized: .feedbackFormCategory), selection: $viewModel.category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.localizedDisplayName).tag(category)
                        }
                    }
                    .labelsHidden()
                    .accessibilityLabel(String(localized: .feedbackFormCategory))
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                GridRow(alignment: .top) {
                    Text(String(localized: .feedbackFormDescription))
                    TextField(
                        String(localized: .feedbackFormDescription),
                        text: $viewModel.description,
                        axis: .vertical
                    )
                    .focused($focusedField, equals: .description)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(String(localized: .feedbackFormDescription))
                    .accessibilityHint(String(localized: .accessibilityFormDescriptionHint))
                }

                if config.showEmailField {
                    GridRow {
                        Text(String(localized: .feedbackFormEmail))
                        VStack(alignment: .leading, spacing: 4) {
                            TextField(String(localized: .feedbackFormEmailPlaceholder), text: $viewModel.email)
                                .focused($focusedField, equals: .email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .onSubmit { submitIfValid() }
                                .accessibilityLabel(String(localized: .feedbackFormEmail))
                                .accessibilityHint(String(localized: .accessibilityFormOptional))
                            Text(String(localized: .feedbackFormEmailFooter))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if config.showMailingListOptIn && !viewModel.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        GridRow {
                            Text("")
                            Toggle(String(localized: .mailingListOptIn), isOn: $viewModel.subscribeToMailingList)
                        }

                        if viewModel.subscribeToMailingList {
                            GridRow {
                                Text("")
                                Toggle(String(localized: .mailingListOperational), isOn: $viewModel.operationalEmails)
                            }
                            GridRow {
                                Text("")
                                Toggle(String(localized: .mailingListMarketing), isOn: $viewModel.marketingEmails)
                            }
                        }
                    }
                }
            }
            .padding()
            .disabled(viewModel.isSubmitting)

            if let unmetRequirement = viewModel.unmetRequirement {
                Text(unmetRequirement)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
            }
        }
    }
    #endif

    // MARK: - Submit Button

    private var submitButton: some View {
        Button(action: submitIfValid) {
            Text(String(localized: .buttonSubmit))
                .font(.body)
        }
        .accessibilityHint(viewModel.isValid ? String(localized: .accessibilitySubmitHint) : (viewModel.unmetRequirement ?? String(localized: .accessibilitySubmitDisabledHint)))
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

