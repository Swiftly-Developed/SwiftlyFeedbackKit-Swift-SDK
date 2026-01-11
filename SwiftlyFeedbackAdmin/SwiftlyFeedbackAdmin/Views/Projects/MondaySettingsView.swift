import SwiftUI

struct MondaySettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var token: String
    @State private var boardId: String
    @State private var boardName: String
    @State private var groupId: String
    @State private var groupName: String
    @State private var syncStatus: Bool
    @State private var syncComments: Bool
    @State private var statusColumnId: String
    @State private var votesColumnId: String
    @State private var isActive: Bool
    @State private var showingTokenInfo = false

    // Board and group selection state
    @State private var boards: [MondayBoard] = []
    @State private var groups: [MondayGroup] = []
    @State private var columns: [MondayColumn] = []
    @State private var selectedBoard: MondayBoard?
    @State private var selectedGroup: MondayGroup?
    @State private var selectedStatusColumn: MondayColumn?
    @State private var selectedVotesColumn: MondayColumn?

    @State private var isLoadingBoards = false
    @State private var isLoadingGroups = false
    @State private var isLoadingColumns = false
    @State private var boardsError: String?
    @State private var showPaywall = false

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _token = State(initialValue: project.mondayToken ?? "")
        _boardId = State(initialValue: project.mondayBoardId ?? "")
        _boardName = State(initialValue: project.mondayBoardName ?? "")
        _groupId = State(initialValue: project.mondayGroupId ?? "")
        _groupName = State(initialValue: project.mondayGroupName ?? "")
        _syncStatus = State(initialValue: project.mondaySyncStatus)
        _syncComments = State(initialValue: project.mondaySyncComments)
        _statusColumnId = State(initialValue: project.mondayStatusColumnId ?? "")
        _votesColumnId = State(initialValue: project.mondayVotesColumnId ?? "")
        _isActive = State(initialValue: project.mondayIsActive)
    }

    private var hasChanges: Bool {
        token != (project.mondayToken ?? "") ||
        boardId != (project.mondayBoardId ?? "") ||
        boardName != (project.mondayBoardName ?? "") ||
        groupId != (project.mondayGroupId ?? "") ||
        groupName != (project.mondayGroupName ?? "") ||
        syncStatus != project.mondaySyncStatus ||
        syncComments != project.mondaySyncComments ||
        statusColumnId != (project.mondayStatusColumnId ?? "") ||
        votesColumnId != (project.mondayVotesColumnId ?? "") ||
        isActive != project.mondayIsActive
    }

    private var isConfigured: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !boardId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Text("When disabled, Monday.com sync will be paused.")
                    }
                }

                Section {
                    SecureField("API Token", text: $token)
                        .onChange(of: token) { _, newValue in
                            if !newValue.isEmpty && boards.isEmpty {
                                loadBoards()
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
                    Text("Find your API token in monday.com: Settings > Developers > My Access Tokens")
                }

                if hasToken {
                    Section {
                        if isLoadingBoards {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading boards...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if let error = boardsError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                            Button("Retry") {
                                loadBoards()
                            }
                        } else {
                            Picker("Board", selection: $selectedBoard) {
                                Text("Select Board").tag(nil as MondayBoard?)
                                ForEach(boards) { board in
                                    Text(board.name).tag(board as MondayBoard?)
                                }
                            }
                            .onChange(of: selectedBoard) { _, newValue in
                                if let board = newValue {
                                    boardId = board.id
                                    boardName = board.name
                                    loadGroups(boardId: board.id)
                                    loadColumns(boardId: board.id)
                                } else {
                                    boardId = ""
                                    boardName = ""
                                    groups = []
                                    columns = []
                                    selectedGroup = nil
                                    selectedStatusColumn = nil
                                    selectedVotesColumn = nil
                                }
                            }
                        }
                    } header: {
                        Text("Target Board")
                    } footer: {
                        if isConfigured {
                            Text("Selected: \(boardName)")
                        } else {
                            Text("Select the monday.com board where items will be created.")
                        }
                    }
                }

                if !boardId.isEmpty {
                    Section {
                        if isLoadingGroups {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading groups...")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Picker("Group", selection: $selectedGroup) {
                                Text("Default (first group)").tag(nil as MondayGroup?)
                                ForEach(groups) { group in
                                    Text(group.title).tag(group as MondayGroup?)
                                }
                            }
                            .onChange(of: selectedGroup) { _, newValue in
                                if let group = newValue {
                                    groupId = group.id
                                    groupName = group.title
                                } else {
                                    groupId = ""
                                    groupName = ""
                                }
                            }
                        }
                    } header: {
                        Text("Target Group")
                    } footer: {
                        Text("Optionally select a specific group within the board. Leave empty to use the default group.")
                    }
                }

                if isConfigured {
                    Section {
                        Toggle("Sync status changes", isOn: $syncStatus)
                        Toggle("Sync comments", isOn: $syncComments)
                    } header: {
                        Text("Sync Options")
                    } footer: {
                        Text("Automatically update monday.com item status when feedback status changes, and add comments as item updates.")
                    }

                    if !columns.isEmpty {
                        let statusColumns = columns.filter { $0.type == "status" || $0.type == "color" }
                        let numberColumns = columns.filter { $0.type == "numbers" }

                        if !statusColumns.isEmpty {
                            Section {
                                Picker("Status Column", selection: $selectedStatusColumn) {
                                    Text("None").tag(nil as MondayColumn?)
                                    ForEach(statusColumns) { column in
                                        Text(column.title).tag(column as MondayColumn?)
                                    }
                                }
                                .onChange(of: selectedStatusColumn) { _, newValue in
                                    statusColumnId = newValue?.id ?? ""
                                }
                            } header: {
                                Text("Status Column")
                            } footer: {
                                Text("Select the Status column to sync feedback status. Status options should include: Pending, Approved, Working on it, In Review, Done, Stuck.")
                            }
                        }

                        if !numberColumns.isEmpty {
                            Section {
                                Picker("Votes Column", selection: $selectedVotesColumn) {
                                    Text("None").tag(nil as MondayColumn?)
                                    ForEach(numberColumns) { column in
                                        Text(column.title).tag(column as MondayColumn?)
                                    }
                                }
                                .onChange(of: selectedVotesColumn) { _, newValue in
                                    votesColumnId = newValue?.id ?? ""
                                }
                            } header: {
                                Text("Vote Count Sync")
                            } footer: {
                                Text("Select a Numbers-type column to sync vote counts.")
                            }
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            clearIntegration()
                        } label: {
                            Label("Remove Monday.com Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Monday.com Integration")
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
            .alert("Get Your Monday.com API Token", isPresented: $showingTokenInfo) {
                Button("Open Monday.com") {
                    if let url = URL(string: "https://monday.com") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("1. Log in to monday.com\n2. Click your avatar > Developers\n3. Go to 'My Access Tokens'\n4. Create a new token or copy an existing one")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(requiredTier: .pro, forceShowPaywall: true)
            }
            .task {
                if hasToken {
                    loadBoards()
                }
            }
        }
    }

    private func loadBoards() {
        guard hasToken else { return }

        isLoadingBoards = true
        boardsError = nil

        Task {
            // First save the token so the API can use it
            let result = await viewModel.updateMondaySettings(
                projectId: project.id,
                mondayToken: token.trimmingCharacters(in: .whitespacesAndNewlines),
                mondayBoardId: nil,
                mondayBoardName: nil,
                mondayGroupId: nil,
                mondayGroupName: nil,
                mondaySyncStatus: nil,
                mondaySyncComments: nil,
                mondayStatusColumnId: nil,
                mondayVotesColumnId: nil,
                mondayIsActive: nil
            )

            if result == .success {
                boards = await viewModel.loadMondayBoards(projectId: project.id)
                if boards.isEmpty {
                    boardsError = "No boards found. Make sure your token has access to at least one board."
                } else {
                    // Pre-select if boardId is already set
                    if !boardId.isEmpty {
                        selectedBoard = boards.first { $0.id == boardId }
                        if selectedBoard != nil {
                            loadGroups(boardId: boardId)
                            loadColumns(boardId: boardId)
                        }
                    }
                }
            } else if result == .paymentRequired {
                showPaywall = true
            } else {
                boardsError = viewModel.errorMessage ?? "Failed to verify token"
            }

            isLoadingBoards = false
        }
    }

    private func loadGroups(boardId: String) {
        isLoadingGroups = true
        Task {
            groups = await viewModel.loadMondayGroups(projectId: project.id, boardId: boardId)

            // Pre-select if groupId is already set
            if !groupId.isEmpty {
                selectedGroup = groups.first { $0.id == groupId }
            }

            isLoadingGroups = false
        }
    }

    private func loadColumns(boardId: String) {
        isLoadingColumns = true
        Task {
            columns = await viewModel.loadMondayColumns(projectId: project.id, boardId: boardId)

            // Pre-select if columns are already set
            if !statusColumnId.isEmpty {
                selectedStatusColumn = columns.first { $0.id == statusColumnId }
            }
            if !votesColumnId.isEmpty {
                selectedVotesColumn = columns.first { $0.id == votesColumnId }
            }

            isLoadingColumns = false
        }
    }

    private func clearIntegration() {
        token = ""
        boardId = ""
        boardName = ""
        groupId = ""
        groupName = ""
        syncStatus = false
        syncComments = false
        statusColumnId = ""
        votesColumnId = ""
        selectedBoard = nil
        selectedGroup = nil
        selectedStatusColumn = nil
        selectedVotesColumn = nil
        boards = []
        groups = []
        columns = []
    }

    private func saveSettings() {
        Task {
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let result = await viewModel.updateMondaySettings(
                projectId: project.id,
                mondayToken: trimmedToken.isEmpty ? "" : trimmedToken,
                mondayBoardId: boardId.isEmpty ? "" : boardId,
                mondayBoardName: boardName.isEmpty ? "" : boardName,
                mondayGroupId: groupId.isEmpty ? "" : groupId,
                mondayGroupName: groupName.isEmpty ? "" : groupName,
                mondaySyncStatus: syncStatus,
                mondaySyncComments: syncComments,
                mondayStatusColumnId: statusColumnId.isEmpty ? "" : statusColumnId,
                mondayVotesColumnId: votesColumnId.isEmpty ? "" : votesColumnId,
                mondayIsActive: isActive
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
    MondaySettingsView(
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
