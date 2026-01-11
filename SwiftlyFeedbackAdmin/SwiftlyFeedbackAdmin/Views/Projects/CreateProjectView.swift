import SwiftUI

struct CreateProjectView: View {
    @Bindable var viewModel: ProjectViewModel
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var showPaywall = false
    @State private var requiredTier: SubscriptionTier = .pro

    private enum Field: Hashable {
        case name, description
    }

    private var isValid: Bool {
        !viewModel.newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // Header Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create a New Project")
                                .font(.headline)

                            Text("Set up a project to start collecting feedback from your users.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Project Details Section
                Section {
                    TextField("Project Name", text: $viewModel.newProjectName)
                        .focused($focusedField, equals: .name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .description
                        }

                    TextField("Description (optional)", text: $viewModel.newProjectDescription, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .lineLimit(3...6)
                } header: {
                    Text("Project Details")
                } footer: {
                    Text("Choose a name that identifies your app or product.")
                }

                // Info Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("API Key")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("You'll receive an API key after creating the project to use with the SDK.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Project")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearAndDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid || viewModel.isLoading)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .interactiveDismissDisabled(viewModel.isLoading)
            .onAppear {
                focusedField = .name
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(requiredTier: requiredTier, forceShowPaywall: true)
            }
            #if os(macOS)
            .frame(minWidth: 400, minHeight: 350)
            #endif
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private func createProject() {
        Task {
            let result = await viewModel.createProject()
            switch result {
            case .success:
                dismiss()
                onDismiss()
            case .paymentRequired(let tier):
                requiredTier = tier
                showPaywall = true
            case .otherError:
                break // Error is shown via viewModel.showError alert
            }
        }
    }

    private func clearAndDismiss() {
        viewModel.newProjectName = ""
        viewModel.newProjectDescription = ""
        dismiss()
        onDismiss()
    }
}

#Preview {
    CreateProjectView(viewModel: ProjectViewModel()) {}
}
