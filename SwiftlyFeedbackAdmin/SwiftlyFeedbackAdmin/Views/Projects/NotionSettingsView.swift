import SwiftUI

struct NotionSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var token: String
    @State private var databaseId: String
    @State private var databaseName: String
    @State private var syncStatus: Bool
    @State private var syncComments: Bool
    @State private var statusProperty: String
    @State private var votesProperty: String
    @State private var isActive: Bool
    @State private var showingTokenInfo = false

    // Database selection state
    @State private var databases: [NotionDatabase] = []
    @State private var selectedDatabase: NotionDatabase?
    @State private var statusProperties: [NotionProperty] = []
    @State private var numberProperties: [NotionProperty] = []
    @State private var selectedStatusProperty: NotionProperty?
    @State private var selectedVotesProperty: NotionProperty?

    @State private var isLoadingDatabases = false
    @State private var databaseError: String?
    @State private var showPaywall = false

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _token = State(initialValue: project.notionToken ?? "")
        _databaseId = State(initialValue: project.notionDatabaseId ?? "")
        _databaseName = State(initialValue: project.notionDatabaseName ?? "")
        _syncStatus = State(initialValue: project.notionSyncStatus)
        _syncComments = State(initialValue: project.notionSyncComments)
        _statusProperty = State(initialValue: project.notionStatusProperty ?? "")
        _votesProperty = State(initialValue: project.notionVotesProperty ?? "")
        _isActive = State(initialValue: project.notionIsActive)
    }

    private var hasChanges: Bool {
        token != (project.notionToken ?? "") ||
        databaseId != (project.notionDatabaseId ?? "") ||
        databaseName != (project.notionDatabaseName ?? "") ||
        syncStatus != project.notionSyncStatus ||
        syncComments != project.notionSyncComments ||
        statusProperty != (project.notionStatusProperty ?? "") ||
        votesProperty != (project.notionVotesProperty ?? "") ||
        isActive != project.notionIsActive
    }

    private var isConfigured: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !databaseId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Text("When disabled, Notion sync will be paused.")
                    }
                }

                Section {
                    SecureField("Integration Token", text: $token)
                        .onChange(of: token) { _, newValue in
                            if !newValue.isEmpty && databases.isEmpty {
                                loadDatabases()
                            }
                        }

                    Button {
                        showingTokenInfo = true
                    } label: {
                        Label("How to create an integration", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Create an Internal Integration at notion.so/my-integrations and share your database with it.")
                }

                if hasToken {
                    Section {
                        if isLoadingDatabases {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading databases...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = databaseError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                            Button("Retry") {
                                loadDatabases()
                            }
                        } else {
                            Picker("Database", selection: $selectedDatabase) {
                                Text("Select Database").tag(nil as NotionDatabase?)
                                ForEach(databases) { database in
                                    Text(database.name).tag(database as NotionDatabase?)
                                }
                            }
                            .onChange(of: selectedDatabase) { _, newValue in
                                if let database = newValue {
                                    databaseId = database.id
                                    databaseName = database.name
                                    loadDatabaseProperties(databaseId: database.id)
                                } else {
                                    databaseId = ""
                                    databaseName = ""
                                    statusProperties = []
                                    numberProperties = []
                                    selectedStatusProperty = nil
                                    selectedVotesProperty = nil
                                }
                            }
                        }
                    } header: {
                        Text("Target Database")
                    } footer: {
                        if isConfigured {
                            Text("Selected: \(databaseName)")
                        } else {
                            Text("Select the Notion database where pages will be created. Make sure the database is shared with your integration.")
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
                        Text("Automatically update Notion page status when feedback status changes, and add comments as page comments.")
                    }

                    if !statusProperties.isEmpty {
                        Section {
                            Picker("Status Property", selection: $selectedStatusProperty) {
                                Text("None").tag(nil as NotionProperty?)
                                ForEach(statusProperties) { prop in
                                    Text(prop.name).tag(prop as NotionProperty?)
                                }
                            }
                            .onChange(of: selectedStatusProperty) { _, newValue in
                                statusProperty = newValue?.name ?? ""
                            }
                        } header: {
                            Text("Status Property")
                        } footer: {
                            Text("Select the Status property to sync feedback status. Status options must include: To Do, Approved, In Progress, In Review, Complete, Closed.")
                        }
                    }

                    if !numberProperties.isEmpty {
                        Section {
                            Picker("Votes Property", selection: $selectedVotesProperty) {
                                Text("None").tag(nil as NotionProperty?)
                                ForEach(numberProperties) { prop in
                                    Text(prop.name).tag(prop as NotionProperty?)
                                }
                            }
                            .onChange(of: selectedVotesProperty) { _, newValue in
                                votesProperty = newValue?.name ?? ""
                            }
                        } header: {
                            Text("Vote Count Sync")
                        } footer: {
                            Text("Select a Number-type property to sync vote counts.")
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            clearIntegration()
                        } label: {
                            Label("Remove Notion Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Notion Integration")
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
            .alert("Create a Notion Integration", isPresented: $showingTokenInfo) {
                Button("Open Notion") {
                    if let url = URL(string: "https://www.notion.so/my-integrations") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("1. Go to notion.so/my-integrations\n2. Create a new Internal Integration\n3. Copy the Integration Secret\n4. Open your target database and share it with the integration (... menu > Add connections)")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(requiredTier: .pro, forceShowPaywall: true)
            }
            .task {
                if hasToken {
                    loadDatabases()
                }
            }
        }
    }

    private func loadDatabases() {
        guard hasToken else { return }

        isLoadingDatabases = true
        databaseError = nil

        Task {
            // First save the token so the API can use it
            let result = await viewModel.updateNotionSettings(
                projectId: project.id,
                notionToken: token.trimmingCharacters(in: .whitespacesAndNewlines),
                notionDatabaseId: nil,
                notionDatabaseName: nil,
                notionSyncStatus: nil,
                notionSyncComments: nil,
                notionStatusProperty: nil,
                notionVotesProperty: nil,
                notionIsActive: nil
            )

            if result == .success {
                databases = await viewModel.loadNotionDatabases(projectId: project.id)
                if databases.isEmpty {
                    databaseError = "No databases found. Make sure you've shared at least one database with the integration."
                } else {
                    // Pre-select if databaseId is already set
                    if !databaseId.isEmpty {
                        selectedDatabase = databases.first { $0.id == databaseId }
                        if selectedDatabase != nil {
                            loadDatabaseProperties(databaseId: databaseId)
                        }
                    }
                }
            } else if result == .paymentRequired {
                showPaywall = true
            } else {
                databaseError = viewModel.errorMessage ?? "Failed to verify token"
            }

            isLoadingDatabases = false
        }
    }

    private func loadDatabaseProperties(databaseId: String) {
        Task {
            if let database = await viewModel.loadNotionDatabaseProperties(projectId: project.id, databaseId: databaseId) {
                statusProperties = database.properties.filter { $0.type == "status" }
                numberProperties = database.properties.filter { $0.type == "number" }

                // Pre-select if properties are already set
                if !statusProperty.isEmpty {
                    selectedStatusProperty = statusProperties.first { $0.name == statusProperty }
                }
                if !votesProperty.isEmpty {
                    selectedVotesProperty = numberProperties.first { $0.name == votesProperty }
                }
            }
        }
    }

    private func clearIntegration() {
        token = ""
        databaseId = ""
        databaseName = ""
        syncStatus = false
        syncComments = false
        statusProperty = ""
        votesProperty = ""
        selectedDatabase = nil
        selectedStatusProperty = nil
        selectedVotesProperty = nil
        databases = []
        statusProperties = []
        numberProperties = []
    }

    private func saveSettings() {
        Task {
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let result = await viewModel.updateNotionSettings(
                projectId: project.id,
                notionToken: trimmedToken.isEmpty ? "" : trimmedToken,
                notionDatabaseId: databaseId.isEmpty ? "" : databaseId,
                notionDatabaseName: databaseName.isEmpty ? "" : databaseName,
                notionSyncStatus: syncStatus,
                notionSyncComments: syncComments,
                notionStatusProperty: statusProperty.isEmpty ? "" : statusProperty,
                notionVotesProperty: votesProperty.isEmpty ? "" : votesProperty,
                notionIsActive: isActive
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

#Preview {
    NotionSettingsView(
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
