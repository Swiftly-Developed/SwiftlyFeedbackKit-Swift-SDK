import SwiftUI

struct GitHubSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var owner: String
    @State private var repo: String
    @State private var token: String
    @State private var defaultLabels: String
    @State private var syncStatus: Bool
    @State private var isActive: Bool
    @State private var showingTokenInfo = false

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _owner = State(initialValue: project.githubOwner ?? "")
        _repo = State(initialValue: project.githubRepo ?? "")
        _token = State(initialValue: project.githubToken ?? "")
        _defaultLabels = State(initialValue: (project.githubDefaultLabels ?? []).joined(separator: ", "))
        _syncStatus = State(initialValue: project.githubSyncStatus)
        _isActive = State(initialValue: project.githubIsActive)
    }

    private var hasChanges: Bool {
        owner != (project.githubOwner ?? "") ||
        repo != (project.githubRepo ?? "") ||
        token != (project.githubToken ?? "") ||
        labelsArray != (project.githubDefaultLabels ?? []) ||
        syncStatus != project.githubSyncStatus ||
        isActive != project.githubIsActive
    }

    private var isConfigured: Bool {
        !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !repo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var labelsArray: [String] {
        defaultLabels
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                if isConfigured {
                    Section {
                        Toggle("Integration Active", isOn: $isActive)
                    } footer: {
                        Text("When disabled, GitHub issue sync will be paused.")
                    }
                }

                Section {
                    TextField("Owner", text: $owner)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()

                    TextField("Repository", text: $repo)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Repository")
                } footer: {
                    Text("e.g., owner: \"apple\", repo: \"swift\"")
                }

                Section {
                    SecureField("Personal Access Token", text: $token)

                    Button {
                        showingTokenInfo = true
                    } label: {
                        Label("How to create a token", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Requires 'repo' scope for private repos, 'public_repo' for public.")
                }

                Section {
                    TextField("Labels (comma-separated)", text: $defaultLabels)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Default Labels")
                } footer: {
                    Text("Labels to apply to all created issues. Feedback category is added automatically.")
                }

                Section {
                    Toggle("Sync status changes", isOn: $syncStatus)
                } header: {
                    Text("Status Sync")
                } footer: {
                    Text("Automatically close GitHub issues when feedback is completed or rejected, and reopen them if the status changes back.")
                }

                if isConfigured {
                    Section {
                        Button(role: .destructive) {
                            owner = ""
                            repo = ""
                            token = ""
                            defaultLabels = ""
                            syncStatus = false
                        } label: {
                            Label("Remove GitHub Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("GitHub Integration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSettings()
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges || viewModel.isLoading)
                }
            }
            .interactiveDismissDisabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
            .alert("Create a Personal Access Token", isPresented: $showingTokenInfo) {
                Button("Open GitHub") {
                    if let url = URL(string: "https://github.com/settings/tokens/new") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Go to GitHub Settings > Developer Settings > Personal Access Tokens > Tokens (classic). Create a token with 'repo' scope for private repos or 'public_repo' for public repos.")
            }
        }
    }

    private func saveSettings() {
        Task {
            let trimmedOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedRepo = repo.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let success = await viewModel.updateGitHubSettings(
                projectId: project.id,
                githubOwner: trimmedOwner.isEmpty ? "" : trimmedOwner,
                githubRepo: trimmedRepo.isEmpty ? "" : trimmedRepo,
                githubToken: trimmedToken.isEmpty ? "" : trimmedToken,
                githubDefaultLabels: labelsArray.isEmpty ? [] : labelsArray,
                githubSyncStatus: syncStatus,
                githubIsActive: isActive
            )
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    GitHubSettingsView(
        project: Project(
            id: UUID(),
            name: "Test Project",
            apiKey: "test-api-key",
            description: "A test description",
            ownerId: UUID(),
            ownerEmail: "test@example.com",
            isArchived: false,
            archivedAt: nil,
            colorIndex: 0,
            feedbackCount: 42,
            memberCount: 5,
            createdAt: Date(),
            updatedAt: Date(),
            slackWebhookUrl: nil,
            slackNotifyNewFeedback: true,
            slackNotifyNewComments: true,
            slackNotifyStatusChanges: true,
            allowedStatuses: ["pending", "approved", "in_progress", "completed", "rejected"],
            githubOwner: nil,
            githubRepo: nil,
            githubToken: nil,
            githubDefaultLabels: nil,
            githubSyncStatus: false,
            githubIsActive: true
        ),
        viewModel: ProjectViewModel()
    )
}
