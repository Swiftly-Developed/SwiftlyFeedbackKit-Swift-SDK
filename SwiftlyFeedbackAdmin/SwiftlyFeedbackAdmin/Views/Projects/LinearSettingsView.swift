import SwiftUI

struct LinearSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var token: String
    @State private var teamId: String
    @State private var teamName: String
    @State private var linearProjectId: String
    @State private var linearProjectName: String
    @State private var selectedLabelIds: Set<String>
    @State private var syncStatus: Bool
    @State private var syncComments: Bool
    @State private var isActive: Bool
    @State private var showingTokenInfo = false

    // Team and project selection state
    @State private var teams: [LinearTeam] = []
    @State private var projects: [LinearProject] = []
    @State private var labels: [LinearLabel] = []
    @State private var selectedTeam: LinearTeam?
    @State private var selectedProject: LinearProject?

    @State private var isLoadingTeams = false
    @State private var isLoadingProjects = false
    @State private var isLoadingLabels = false
    @State private var teamsError: String?
    @State private var showPaywall = false

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _token = State(initialValue: project.linearToken ?? "")
        _teamId = State(initialValue: project.linearTeamId ?? "")
        _teamName = State(initialValue: project.linearTeamName ?? "")
        _linearProjectId = State(initialValue: project.linearProjectId ?? "")
        _linearProjectName = State(initialValue: project.linearProjectName ?? "")
        _selectedLabelIds = State(initialValue: Set(project.linearDefaultLabelIds ?? []))
        _syncStatus = State(initialValue: project.linearSyncStatus)
        _syncComments = State(initialValue: project.linearSyncComments)
        _isActive = State(initialValue: project.linearIsActive)
    }

    private var hasChanges: Bool {
        token != (project.linearToken ?? "") ||
        teamId != (project.linearTeamId ?? "") ||
        teamName != (project.linearTeamName ?? "") ||
        linearProjectId != (project.linearProjectId ?? "") ||
        linearProjectName != (project.linearProjectName ?? "") ||
        Array(selectedLabelIds).sorted() != (project.linearDefaultLabelIds ?? []).sorted() ||
        syncStatus != project.linearSyncStatus ||
        syncComments != project.linearSyncComments ||
        isActive != project.linearIsActive
    }

    private var isConfigured: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !teamId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasToken: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                if isConfigured {
                    Section {
                        Toggle("Integration Active", isOn: $isActive)
                    } footer: {
                        Text("When disabled, Linear sync will be paused.")
                    }
                }

                Section {
                    SecureField("API Token", text: $token)
                        .onChange(of: token) { _, newValue in
                            if !newValue.isEmpty && teams.isEmpty {
                                loadTeams()
                            }
                        }

                    Button {
                        showingTokenInfo = true
                    } label: {
                        Label("How to get your API token", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Create a Personal API Key in Linear: Settings > API > Personal API Keys")
                }

                if hasToken {
                    Section {
                        if isLoadingTeams {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading teams...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = teamsError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                            Button("Retry") {
                                loadTeams()
                            }
                        } else {
                            Picker("Team", selection: $selectedTeam) {
                                Text("Select Team").tag(nil as LinearTeam?)
                                ForEach(teams) { team in
                                    Text("\(team.name) (\(team.key))").tag(team as LinearTeam?)
                                }
                            }
                            .onChange(of: selectedTeam) { _, newValue in
                                if let team = newValue {
                                    teamId = team.id
                                    teamName = team.name
                                    loadProjects(teamId: team.id)
                                    loadLabels(teamId: team.id)
                                } else {
                                    teamId = ""
                                    teamName = ""
                                    projects = []
                                    labels = []
                                    selectedProject = nil
                                    linearProjectId = ""
                                    linearProjectName = ""
                                    selectedLabelIds = []
                                }
                            }
                        }
                    } header: {
                        Text("Target Team")
                    } footer: {
                        if isConfigured {
                            Text("Selected: \(teamName)")
                        } else {
                            Text("Select the Linear team where issues will be created.")
                        }
                    }
                }

                if !teamId.isEmpty {
                    Section {
                        if isLoadingProjects {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading projects...")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Picker("Project", selection: $selectedProject) {
                                Text("No project (backlog only)").tag(nil as LinearProject?)
                                ForEach(projects.filter { $0.state != "canceled" }) { proj in
                                    Text(proj.name).tag(proj as LinearProject?)
                                }
                            }
                            .onChange(of: selectedProject) { _, newValue in
                                if let proj = newValue {
                                    linearProjectId = proj.id
                                    linearProjectName = proj.name
                                } else {
                                    linearProjectId = ""
                                    linearProjectName = ""
                                }
                            }
                        }
                    } header: {
                        Text("Project (Optional)")
                    } footer: {
                        Text("Optionally assign issues to a specific Linear project. Leave empty to create issues in the team backlog.")
                    }

                    if !labels.isEmpty {
                        Section {
                            ForEach(labels) { label in
                                Toggle(isOn: Binding(
                                    get: { selectedLabelIds.contains(label.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedLabelIds.insert(label.id)
                                        } else {
                                            selectedLabelIds.remove(label.id)
                                        }
                                    }
                                )) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: label.color) ?? .gray)
                                            .frame(width: 12, height: 12)
                                        Text(label.name)
                                    }
                                }
                            }
                        } header: {
                            Text("Default Labels")
                        } footer: {
                            Text("Select labels to apply to all created issues.")
                        }
                    }
                }

                if isConfigured {
                    Section {
                        Toggle("Sync status changes", isOn: $syncStatus)
                        Toggle("Sync comments", isOn: $syncComments)
                    } header: {
                        Text("Sync Options")
                    } footer: {
                        Text("Automatically update Linear issue status when feedback status changes, and sync comments to issues.")
                    }

                    Section {
                        Button(role: .destructive) {
                            clearIntegration()
                        } label: {
                            Label("Remove Linear Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Linear Integration")
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
            .alert("Get Your Linear API Token", isPresented: $showingTokenInfo) {
                Button("Open Linear Settings") {
                    if let url = URL(string: "https://linear.app/settings/api") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("1. Open Linear and go to Settings\n2. Navigate to API section\n3. Click 'Personal API Keys'\n4. Create a new key and copy it")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(requiredTier: .pro, forceShowPaywall: true)
            }
            .task {
                if hasToken {
                    loadTeams()
                }
            }
        }
    }

    private func loadTeams() {
        guard hasToken else { return }

        isLoadingTeams = true
        teamsError = nil

        Task {
            // First save the token so the API can use it
            let result = await viewModel.updateLinearSettings(
                projectId: project.id,
                linearToken: token.trimmingCharacters(in: .whitespacesAndNewlines),
                linearTeamId: nil,
                linearTeamName: nil,
                linearProjectId: nil,
                linearProjectName: nil,
                linearDefaultLabelIds: nil,
                linearSyncStatus: nil,
                linearSyncComments: nil,
                linearIsActive: nil
            )

            if result == .success {
                teams = await viewModel.loadLinearTeams(projectId: project.id)
                if teams.isEmpty {
                    teamsError = "No teams found. Make sure your token is valid."
                } else {
                    // Pre-select if teamId is already set
                    if !teamId.isEmpty {
                        selectedTeam = teams.first { $0.id == teamId }
                        if selectedTeam != nil {
                            loadProjects(teamId: teamId)
                            loadLabels(teamId: teamId)
                        }
                    }
                }
            } else if result == .paymentRequired {
                showPaywall = true
            } else {
                teamsError = viewModel.errorMessage ?? "Failed to verify token"
            }

            isLoadingTeams = false
        }
    }

    private func loadProjects(teamId: String) {
        isLoadingProjects = true
        Task {
            projects = await viewModel.loadLinearProjects(projectId: project.id, teamId: teamId)

            // Pre-select if linearProjectId is already set
            if !linearProjectId.isEmpty {
                selectedProject = projects.first { $0.id == linearProjectId }
            }

            isLoadingProjects = false
        }
    }

    private func loadLabels(teamId: String) {
        isLoadingLabels = true
        Task {
            labels = await viewModel.loadLinearLabels(projectId: project.id, teamId: teamId)
            isLoadingLabels = false
        }
    }

    private func clearIntegration() {
        token = ""
        teamId = ""
        teamName = ""
        linearProjectId = ""
        linearProjectName = ""
        selectedLabelIds = []
        syncStatus = false
        syncComments = false
        selectedTeam = nil
        selectedProject = nil
        teams = []
        projects = []
        labels = []
    }

    private func saveSettings() {
        Task {
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let result = await viewModel.updateLinearSettings(
                projectId: project.id,
                linearToken: trimmedToken.isEmpty ? "" : trimmedToken,
                linearTeamId: teamId.isEmpty ? "" : teamId,
                linearTeamName: teamName.isEmpty ? "" : teamName,
                linearProjectId: linearProjectId.isEmpty ? "" : linearProjectId,
                linearProjectName: linearProjectName.isEmpty ? "" : linearProjectName,
                linearDefaultLabelIds: Array(selectedLabelIds),
                linearSyncStatus: syncStatus,
                linearSyncComments: syncComments,
                linearIsActive: isActive
            )
            switch result {
            case .success:
                dismiss()
            case .paymentRequired:
                showPaywall = true
            case .otherError:
                break
            }
        }
    }
}

// Color extension to parse hex colors from Linear
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    LinearSettingsView(
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
            allowedStatuses: ["pending", "approved", "in_progress", "completed", "rejected"]
        ),
        viewModel: ProjectViewModel()
    )
}
