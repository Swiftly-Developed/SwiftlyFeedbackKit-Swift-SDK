import SwiftUI

public struct SubmitFeedbackView: View {
    let swiftlyFeedback: SwiftlyFeedback?
    let onDismiss: () -> Void

    @StateObject private var viewModel = SubmitFeedbackViewModel()
    @Environment(\.dismiss) private var dismiss

    public init(swiftlyFeedback: SwiftlyFeedback? = nil, onDismiss: @escaping () -> Void = {}) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $viewModel.title)

                    Picker("Category", selection: $viewModel.category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                }

                Section("Description") {
                    TextEditor(text: $viewModel.description)
                        .frame(minHeight: 100)
                }

                Section("Optional") {
                    TextField("Email (for follow-up)", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
            .navigationTitle("Submit Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        Task {
                            await viewModel.submit(using: swiftlyFeedback)
                            if viewModel.isSubmitted {
                                dismiss()
                                onDismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSubmitting)
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Failed to submit feedback")
            }
            .overlay {
                if viewModel.isSubmitting {
                    ProgressView("Submitting...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

@MainActor
final class SubmitFeedbackViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var category: FeedbackCategory = .featureRequest
    @Published var email = ""
    @Published var isSubmitting = false
    @Published var isSubmitted = false
    @Published var showingError = false
    @Published var errorMessage: String?

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
