import SwiftUI

struct ClickUpSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var token: String
    @State private var listId: String
    @State private var workspaceName: String
    @State private var listName: String
    @State private var defaultTags: String
    @State private var syncStatus: Bool
    @State private var syncComments: Bool
    @State private var votesFieldId: String
    @State private var showingTokenInfo = false

    // Hierarchy selection state
    @State private var workspaces: [ClickUpWorkspace] = []
    @State private var spaces: [ClickUpSpace] = []
    @State private var folders: [ClickUpFolder] = []
    @State private var lists: [ClickUpList] = []
    @State private var folderlessLists: [ClickUpList] = []
    @State private var customFields: [ClickUpCustomField] = []

    @State private var selectedWorkspace: ClickUpWorkspace?
    @State private var selectedSpace: ClickUpSpace?
    @State private var selectedFolder: ClickUpFolder?
    @State private var selectedList: ClickUpList?
    @State private var selectedCustomField: ClickUpCustomField?

    @State private var isLoadingHierarchy = false
    @State private var hierarchyError: String?

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _token = State(initialValue: project.clickupToken ?? "")
        _listId = State(initialValue: project.clickupListId ?? "")
        _workspaceName = State(initialValue: project.clickupWorkspaceName ?? "")
        _listName = State(initialValue: project.clickupListName ?? "")
        _defaultTags = State(initialValue: (project.clickupDefaultTags ?? []).joined(separator: ", "))
        _syncStatus = State(initialValue: project.clickupSyncStatus)
        _syncComments = State(initialValue: project.clickupSyncComments)
        _votesFieldId = State(initialValue: project.clickupVotesFieldId ?? "")
    }

    private var hasChanges: Bool {
        token != (project.clickupToken ?? "") ||
        listId != (project.clickupListId ?? "") ||
        workspaceName != (project.clickupWorkspaceName ?? "") ||
        listName != (project.clickupListName ?? "") ||
        tagsArray != (project.clickupDefaultTags ?? []) ||
        syncStatus != project.clickupSyncStatus ||
        syncComments != project.clickupSyncComments ||
        votesFieldId != (project.clickupVotesFieldId ?? "")
    }

    private var isConfigured: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !listId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tagsArray: [String] {
        defaultTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var hasToken: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("API Token", text: $token)
                        .onChange(of: token) { _, newValue in
                            if !newValue.isEmpty && workspaces.isEmpty {
                                loadWorkspaces()
                            }
                        }

                    Button {
                        showingTokenInfo = true
                    } label: {
                        Label("How to create a token", systemImage: "questionmark.circle")
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text("Get your API token from ClickUp Settings > Apps.")
                }

                if hasToken {
                    Section {
                        if isLoadingHierarchy {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = hierarchyError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                            Button("Retry") {
                                loadWorkspaces()
                            }
                        } else {
                            // Workspace picker
                            Picker("Workspace", selection: $selectedWorkspace) {
                                Text("Select Workspace").tag(nil as ClickUpWorkspace?)
                                ForEach(workspaces) { workspace in
                                    Text(workspace.name).tag(workspace as ClickUpWorkspace?)
                                }
                            }
                            .onChange(of: selectedWorkspace) { _, newValue in
                                selectedSpace = nil
                                selectedFolder = nil
                                selectedList = nil
                                spaces = []
                                folders = []
                                lists = []
                                folderlessLists = []
                                if let workspace = newValue {
                                    loadSpaces(workspaceId: workspace.id)
                                }
                            }

                            // Space picker
                            if selectedWorkspace != nil {
                                Picker("Space", selection: $selectedSpace) {
                                    Text("Select Space").tag(nil as ClickUpSpace?)
                                    ForEach(spaces) { space in
                                        Text(space.name).tag(space as ClickUpSpace?)
                                    }
                                }
                                .onChange(of: selectedSpace) { _, newValue in
                                    selectedFolder = nil
                                    selectedList = nil
                                    folders = []
                                    lists = []
                                    folderlessLists = []
                                    if let space = newValue {
                                        loadFolders(spaceId: space.id)
                                        loadFolderlessLists(spaceId: space.id)
                                    }
                                }
                            }

                            // Folder picker (optional)
                            if selectedSpace != nil && !folders.isEmpty {
                                Picker("Folder (optional)", selection: $selectedFolder) {
                                    Text("No Folder").tag(nil as ClickUpFolder?)
                                    ForEach(folders) { folder in
                                        Text(folder.name).tag(folder as ClickUpFolder?)
                                    }
                                }
                                .onChange(of: selectedFolder) { _, newValue in
                                    selectedList = nil
                                    lists = []
                                    if let folder = newValue {
                                        loadLists(folderId: folder.id)
                                    }
                                }
                            }

                            // List picker
                            if selectedSpace != nil {
                                let availableLists = selectedFolder != nil ? lists : folderlessLists
                                Picker("List", selection: $selectedList) {
                                    Text("Select List").tag(nil as ClickUpList?)
                                    ForEach(availableLists) { list in
                                        Text(list.name).tag(list as ClickUpList?)
                                    }
                                }
                                .onChange(of: selectedList) { _, newValue in
                                    if let list = newValue {
                                        listId = list.id
                                        listName = list.name
                                        workspaceName = selectedWorkspace?.name ?? ""
                                        loadCustomFields()
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Target List")
                    } footer: {
                        if isConfigured {
                            Text("Selected: \(workspaceName) / \(listName)")
                        } else {
                            Text("Select the ClickUp list where tasks will be created.")
                        }
                    }
                }

                Section {
                    TextField("Tags (comma-separated)", text: $defaultTags)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                } header: {
                    Text("Default Tags")
                } footer: {
                    Text("Tags to apply to all created tasks. Feedback category is added automatically.")
                }

                Section {
                    Toggle("Sync status changes", isOn: $syncStatus)
                    Toggle("Sync comments", isOn: $syncComments)
                } header: {
                    Text("Sync Options")
                } footer: {
                    Text("Automatically update ClickUp task status when feedback status changes, and add comments to tasks.")
                }

                if isConfigured && !customFields.isEmpty {
                    Section {
                        Picker("Votes Field", selection: $selectedCustomField) {
                            Text("None").tag(nil as ClickUpCustomField?)
                            ForEach(customFields) { field in
                                Text(field.name).tag(field as ClickUpCustomField?)
                            }
                        }
                        .onChange(of: selectedCustomField) { _, newValue in
                            votesFieldId = newValue?.id ?? ""
                        }
                    } header: {
                        Text("Vote Count Sync")
                    } footer: {
                        Text("Select a Number-type custom field to sync vote counts.")
                    }
                }

                if isConfigured {
                    Section {
                        Button(role: .destructive) {
                            token = ""
                            listId = ""
                            workspaceName = ""
                            listName = ""
                            defaultTags = ""
                            syncStatus = false
                            syncComments = false
                            votesFieldId = ""
                            selectedWorkspace = nil
                            selectedSpace = nil
                            selectedFolder = nil
                            selectedList = nil
                            selectedCustomField = nil
                            workspaces = []
                            spaces = []
                            folders = []
                            lists = []
                            folderlessLists = []
                            customFields = []
                        } label: {
                            Label("Remove ClickUp Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("ClickUp Integration")
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
            .alert("Get Your ClickUp API Token", isPresented: $showingTokenInfo) {
                Button("Open ClickUp") {
                    if let url = URL(string: "https://app.clickup.com/settings/apps") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Go to ClickUp Settings > Apps > API Token. Copy your personal API token.")
            }
            .task {
                // Load workspaces if token exists
                if hasToken {
                    loadWorkspaces()
                }
            }
        }
    }

    private func loadWorkspaces() {
        guard hasToken else { return }

        isLoadingHierarchy = true
        hierarchyError = nil

        Task {
            // First save the token so the API can use it
            let success = await viewModel.updateClickUpSettings(
                projectId: project.id,
                clickupToken: token.trimmingCharacters(in: .whitespacesAndNewlines),
                clickupListId: nil,
                clickupWorkspaceName: nil,
                clickupListName: nil,
                clickupDefaultTags: nil,
                clickupSyncStatus: nil,
                clickupSyncComments: nil,
                clickupVotesFieldId: nil
            )

            if success {
                workspaces = await viewModel.loadClickUpWorkspaces(projectId: project.id)
                if workspaces.isEmpty {
                    hierarchyError = "No workspaces found. Check your API token."
                }
            } else {
                hierarchyError = viewModel.errorMessage ?? "Failed to verify token"
            }

            isLoadingHierarchy = false
        }
    }

    private func loadSpaces(workspaceId: String) {
        isLoadingHierarchy = true
        Task {
            spaces = await viewModel.loadClickUpSpaces(projectId: project.id, workspaceId: workspaceId)
            isLoadingHierarchy = false
        }
    }

    private func loadFolders(spaceId: String) {
        Task {
            folders = await viewModel.loadClickUpFolders(projectId: project.id, spaceId: spaceId)
        }
    }

    private func loadLists(folderId: String) {
        Task {
            lists = await viewModel.loadClickUpLists(projectId: project.id, folderId: folderId)
        }
    }

    private func loadFolderlessLists(spaceId: String) {
        Task {
            folderlessLists = await viewModel.loadClickUpFolderlessLists(projectId: project.id, spaceId: spaceId)
        }
    }

    private func loadCustomFields() {
        Task {
            customFields = await viewModel.loadClickUpCustomFields(projectId: project.id)
            // Pre-select if votesFieldId is already set
            if !votesFieldId.isEmpty {
                selectedCustomField = customFields.first { $0.id == votesFieldId }
            }
        }
    }

    private func saveSettings() {
        Task {
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let success = await viewModel.updateClickUpSettings(
                projectId: project.id,
                clickupToken: trimmedToken.isEmpty ? "" : trimmedToken,
                clickupListId: listId.isEmpty ? "" : listId,
                clickupWorkspaceName: workspaceName.isEmpty ? "" : workspaceName,
                clickupListName: listName.isEmpty ? "" : listName,
                clickupDefaultTags: tagsArray.isEmpty ? [] : tagsArray,
                clickupSyncStatus: syncStatus,
                clickupSyncComments: syncComments,
                clickupVotesFieldId: votesFieldId.isEmpty ? "" : votesFieldId
            )
            if success {
                dismiss()
            }
        }
    }
}

#Preview {
    ClickUpSettingsView(
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
            clickupToken: nil,
            clickupListId: nil,
            clickupWorkspaceName: nil,
            clickupListName: nil,
            clickupDefaultTags: nil,
            clickupSyncStatus: false,
            clickupSyncComments: false,
            clickupVotesFieldId: nil
        ),
        viewModel: ProjectViewModel()
    )
}
