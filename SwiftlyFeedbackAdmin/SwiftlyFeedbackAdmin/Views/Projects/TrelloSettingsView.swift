import SwiftUI

struct TrelloSettingsView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var token: String
    @State private var boardId: String
    @State private var boardName: String
    @State private var listId: String
    @State private var listName: String
    @State private var syncStatus: Bool
    @State private var syncComments: Bool
    @State private var isActive: Bool
    @State private var showingTokenInfo = false

    // Board and list selection state
    @State private var boards: [TrelloBoard] = []
    @State private var lists: [TrelloList] = []
    @State private var selectedBoard: TrelloBoard?
    @State private var selectedList: TrelloList?

    @State private var isLoadingBoards = false
    @State private var isLoadingLists = false
    @State private var boardsError: String?
    @State private var showPaywall = false

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _token = State(initialValue: project.trelloToken ?? "")
        _boardId = State(initialValue: project.trelloBoardId ?? "")
        _boardName = State(initialValue: project.trelloBoardName ?? "")
        _listId = State(initialValue: project.trelloListId ?? "")
        _listName = State(initialValue: project.trelloListName ?? "")
        _syncStatus = State(initialValue: project.trelloSyncStatus)
        _syncComments = State(initialValue: project.trelloSyncComments)
        _isActive = State(initialValue: project.trelloIsActive)
    }

    private var hasChanges: Bool {
        token != (project.trelloToken ?? "") ||
        boardId != (project.trelloBoardId ?? "") ||
        boardName != (project.trelloBoardName ?? "") ||
        listId != (project.trelloListId ?? "") ||
        listName != (project.trelloListName ?? "") ||
        syncStatus != project.trelloSyncStatus ||
        syncComments != project.trelloSyncComments ||
        isActive != project.trelloIsActive
    }

    private var isConfigured: Bool {
        !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !boardId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !listId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        Text("When disabled, Trello sync will be paused.")
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
                    Text("Get your API token from trello.com/power-ups/admin. You'll need both an API key and token.")
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
                                Text("Select Board").tag(nil as TrelloBoard?)
                                ForEach(boards) { board in
                                    Text(board.name).tag(board as TrelloBoard?)
                                }
                            }
                            .onChange(of: selectedBoard) { _, newValue in
                                if let board = newValue {
                                    boardId = board.id
                                    boardName = board.name
                                    loadLists(boardId: board.id)
                                } else {
                                    boardId = ""
                                    boardName = ""
                                    lists = []
                                    selectedList = nil
                                    listId = ""
                                    listName = ""
                                }
                            }
                        }
                    } header: {
                        Text("Target Board")
                    } footer: {
                        if isConfigured {
                            Text("Selected: \(boardName)")
                        } else {
                            Text("Select the Trello board where cards will be created.")
                        }
                    }
                }

                if !boardId.isEmpty {
                    Section {
                        if isLoadingLists {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading lists...")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Picker("List", selection: $selectedList) {
                                Text("Select List").tag(nil as TrelloList?)
                                ForEach(lists) { list in
                                    Text(list.name).tag(list as TrelloList?)
                                }
                            }
                            .onChange(of: selectedList) { _, newValue in
                                if let list = newValue {
                                    listId = list.id
                                    listName = list.name
                                } else {
                                    listId = ""
                                    listName = ""
                                }
                            }
                        }
                    } header: {
                        Text("Target List")
                    } footer: {
                        if !listId.isEmpty {
                            Text("Selected: \(listName)")
                        } else {
                            Text("Select the list where new cards will be added.")
                        }
                    }
                }

                if isConfigured {
                    Section {
                        Toggle("Sync comments", isOn: $syncComments)
                    } header: {
                        Text("Sync Options")
                    } footer: {
                        Text("Automatically sync comments to Trello cards.")
                    }

                    Section {
                        Button(role: .destructive) {
                            clearIntegration()
                        } label: {
                            Label("Remove Trello Integration", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Trello Integration")
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
            .alert("Get Your Trello API Token", isPresented: $showingTokenInfo) {
                Button("Open Trello Power-Ups") {
                    if let url = URL(string: "https://trello.com/power-ups/admin") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("1. Open trello.com/power-ups/admin\n2. Create a new Power-Up or select existing\n3. Generate an API key\n4. Click to generate a token\n5. Copy and paste the token here")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(requiredTier: .pro)
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
            let result = await viewModel.updateTrelloSettings(
                projectId: project.id,
                trelloToken: token.trimmingCharacters(in: .whitespacesAndNewlines),
                trelloBoardId: nil,
                trelloBoardName: nil,
                trelloListId: nil,
                trelloListName: nil,
                trelloSyncStatus: nil,
                trelloSyncComments: nil,
                trelloIsActive: nil
            )

            if result == .success {
                boards = await viewModel.loadTrelloBoards(projectId: project.id)
                if boards.isEmpty {
                    boardsError = "No boards found. Make sure your token is valid."
                } else {
                    // Pre-select if boardId is already set
                    if !boardId.isEmpty {
                        selectedBoard = boards.first { $0.id == boardId }
                        if selectedBoard != nil {
                            loadLists(boardId: boardId)
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

    private func loadLists(boardId: String) {
        isLoadingLists = true
        Task {
            lists = await viewModel.loadTrelloLists(projectId: project.id, boardId: boardId)

            // Pre-select if listId is already set
            if !listId.isEmpty {
                selectedList = lists.first { $0.id == listId }
            }

            isLoadingLists = false
        }
    }

    private func clearIntegration() {
        token = ""
        boardId = ""
        boardName = ""
        listId = ""
        listName = ""
        syncStatus = false
        syncComments = false
        selectedBoard = nil
        selectedList = nil
        boards = []
        lists = []
    }

    private func saveSettings() {
        Task {
            let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)

            let result = await viewModel.updateTrelloSettings(
                projectId: project.id,
                trelloToken: trimmedToken.isEmpty ? "" : trimmedToken,
                trelloBoardId: boardId.isEmpty ? "" : boardId,
                trelloBoardName: boardName.isEmpty ? "" : boardName,
                trelloListId: listId.isEmpty ? "" : listId,
                trelloListName: listName.isEmpty ? "" : listName,
                trelloSyncStatus: syncStatus,
                trelloSyncComments: syncComments,
                trelloIsActive: isActive
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
    TrelloSettingsView(
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
