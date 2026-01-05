import SwiftUI

// MARK: - View Mode

enum FeedbackViewMode: String, CaseIterable {
    case list
    case kanban

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .kanban: return "rectangle.3.group"
        }
    }

    var label: String {
        switch self {
        case .list: return "List"
        case .kanban: return "Kanban"
        }
    }
}

// MARK: - Main View

struct FeedbackListView: View {
    let project: Project
    @Bindable var viewModel: FeedbackViewModel
    @AppStorage("feedbackViewMode") private var viewMode: FeedbackViewMode = .list
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedFeedbackId: UUID?
    @State private var feedbackToOpen: Feedback?

    var body: some View {
        ZStack(alignment: .bottom) {
            feedbackListContent
                .navigationTitle("Feedback")
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        viewModePicker
                    }
                    #else
                    ToolbarItem(placement: .automatic) {
                        viewModePicker
                    }
                    #endif

                    ToolbarItem(placement: .primaryAction) {
                        filterMenu
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: "Search feedback...")
                .task {
                    await viewModel.loadFeedbacks(projectId: project.id, apiKey: project.apiKey)
                }
                #if os(iOS)
                .refreshable {
                    await viewModel.refreshFeedbacks()
                }
                #endif

            // Selection action bar (shows when 2+ items selected)
            if viewModel.canMerge {
                selectionActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: viewModel.canMerge)
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $viewModel.showSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.successMessage ?? "Operation completed")
        }
        .sheet(isPresented: $viewModel.showMergeSheet) {
            MergeFeedbackSheet(viewModel: viewModel)
        }
        .navigationDestination(for: Feedback.self) { feedback in
            FeedbackDetailView(
                feedback: feedback,
                apiKey: project.apiKey,
                allowedStatuses: allowedStatuses,
                viewModel: viewModel
            )
        }
        .navigationDestination(item: $feedbackToOpen) { feedback in
            FeedbackDetailView(
                feedback: feedback,
                apiKey: project.apiKey,
                allowedStatuses: allowedStatuses,
                viewModel: viewModel
            )
        }
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        HStack {
            Text("\(viewModel.selectedFeedbackIds.count) items selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                viewModel.clearSelection()
            } label: {
                Text("Clear")
            }
            .buttonStyle(.bordered)

            Spacer()

            // GitHub push button (only show if GitHub is configured)
            if project.isGitHubConfigured {
                Button {
                    Task {
                        await viewModel.bulkCreateGitHubIssues(projectId: project.id)
                    }
                } label: {
                    Label("Push to GitHub", systemImage: "arrow.triangle.branch")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedFeedbacks.allSatisfy { $0.hasGitHubIssue })
            }

            // ClickUp push button (only show if ClickUp is configured)
            if project.isClickUpConfigured {
                Button {
                    Task {
                        await viewModel.bulkCreateClickUpTasks(projectId: project.id)
                    }
                } label: {
                    Label("Push to ClickUp", systemImage: "checklist")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.selectedFeedbacks.allSatisfy { $0.hasClickUpTask })
            }

            Button {
                viewModel.startMergeWithSelection()
            } label: {
                Label("Merge Selected", systemImage: "arrow.triangle.merge")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        #if os(macOS)
        .background(.regularMaterial)
        #else
        .background(.ultraThinMaterial)
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        .padding()
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(FeedbackViewMode.allCases, id: \.self) { mode in
                Label(mode.label, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        #if os(iOS)
        .frame(width: horizontalSizeClass == .compact ? 100 : 130)
        #else
        .frame(width: 130)
        #endif
    }

    // MARK: - Allowed Statuses

    private var allowedStatuses: [FeedbackStatus] {
        let allowedSet = Set(project.allowedStatuses)
        // Filter allCases to maintain proper order
        return FeedbackStatus.allCases.filter { allowedSet.contains($0.rawValue) }
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            // Sort menu
            Menu {
                ForEach(FeedbackSortOption.allCases, id: \.self) { option in
                    Button {
                        viewModel.sortOption = option
                    } label: {
                        HStack {
                            Label(option.displayName, systemImage: option.icon)
                            Spacer()
                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort by", systemImage: "arrow.up.arrow.down")
            }

            Divider()

            // Status filter
            Menu {
                Button {
                    viewModel.statusFilter = nil
                } label: {
                    HStack {
                        Text("All Statuses")
                        Spacer()
                        if viewModel.statusFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(allowedStatuses, id: \.self) { status in
                    Button {
                        viewModel.statusFilter = status
                    } label: {
                        HStack {
                            Text(status.displayName)
                            Spacer()
                            if viewModel.statusFilter == status {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Status", systemImage: "flag")
            }

            // Category filter
            Menu {
                Button {
                    viewModel.categoryFilter = nil
                } label: {
                    HStack {
                        Text("All Categories")
                        Spacer()
                        if viewModel.categoryFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                    Button {
                        viewModel.categoryFilter = category
                    } label: {
                        HStack {
                            Text(category.displayName)
                            Spacer()
                            if viewModel.categoryFilter == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Category", systemImage: "tag")
            }

            if viewModel.statusFilter != nil || viewModel.categoryFilter != nil || viewModel.sortOption != .votes {
                Divider()

                Button(role: .destructive) {
                    viewModel.clearFilters()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(systemName: activeFiltersCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    private var activeFiltersCount: Int {
        var count = 0
        if viewModel.statusFilter != nil { count += 1 }
        if viewModel.categoryFilter != nil { count += 1 }
        if viewModel.sortOption != .votes { count += 1 }
        return count
    }

    // MARK: - Content

    @ViewBuilder
    private var feedbackListContent: some View {
        Group {
            if viewModel.isLoading && viewModel.feedbacks.isEmpty {
                ProgressView("Loading feedback...")
            } else if viewModel.feedbacks.isEmpty {
                emptyState
            } else if viewModel.filteredFeedbacks.isEmpty {
                noResultsState
            } else {
                switch viewMode {
                case .list:
                    listView
                case .kanban:
                    kanbanView
                }
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        List(selection: $viewModel.selectedFeedbackIds) {
            ForEach(viewModel.filteredFeedbacks) { feedback in
                #if os(macOS)
                // macOS: Single click selects, double click opens
                FeedbackListRowView(feedback: feedback, showMergeBadge: feedback.hasMergedFeedback)
                    .tag(feedback.id)
                    .onTapGesture(count: 2) {
                        feedbackToOpen = feedback
                    }
                    .onTapGesture(count: 1) {
                        viewModel.toggleSelection(feedback.id)
                    }
                    .contextMenu {
                        Button {
                            feedbackToOpen = feedback
                        } label: {
                            Label("Open", systemImage: "arrow.right.circle")
                        }
                        Divider()
                        feedbackContextMenuItems(for: feedback)
                    }
                #else
                // iOS: Single tap opens (standard behavior)
                NavigationLink(value: feedback) {
                    FeedbackListRowView(feedback: feedback, showMergeBadge: feedback.hasMergedFeedback)
                }
                .tag(feedback.id)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteFeedback(id: feedback.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    feedbackContextMenuItems(for: feedback)
                }
                #endif
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Context Menu Items

    @ViewBuilder
    private func feedbackContextMenuItems(for feedback: Feedback) -> some View {
        // GitHub options
        if project.isGitHubConfigured {
            if feedback.hasGitHubIssue {
                if let issueUrl = feedback.githubIssueUrl, let url = URL(string: issueUrl) {
                    Link(destination: url) {
                        Label("View GitHub Issue", systemImage: "link")
                    }
                }
            } else {
                Button {
                    Task {
                        await viewModel.createGitHubIssue(projectId: project.id, feedbackId: feedback.id)
                    }
                } label: {
                    Label("Push to GitHub", systemImage: "arrow.triangle.branch")
                }
            }
            Divider()
        }

        // ClickUp options
        if project.isClickUpConfigured {
            if feedback.hasClickUpTask {
                if let taskUrl = feedback.clickupTaskUrl, let url = URL(string: taskUrl) {
                    Link(destination: url) {
                        Label("View ClickUp Task", systemImage: "link")
                    }
                }
            } else {
                Button {
                    Task {
                        await viewModel.createClickUpTask(projectId: project.id, feedbackId: feedback.id)
                    }
                } label: {
                    Label("Push to ClickUp", systemImage: "checklist")
                }
            }
            Divider()
        }

        // Merge option (shows when this + selected >= 2)
        let canMergeThis = viewModel.selectedFeedbackIds.count >= 1 || viewModel.selectedFeedbackIds.contains(feedback.id)
        if canMergeThis {
            Button {
                viewModel.startMerge(with: feedback)
            } label: {
                let count = viewModel.selectedFeedbackIds.contains(feedback.id)
                    ? viewModel.selectedFeedbackIds.count
                    : viewModel.selectedFeedbackIds.count + 1
                Label("Merge \(count) Items...", systemImage: "arrow.triangle.merge")
            }
            .disabled(viewModel.selectedFeedbackIds.count == 0 && !viewModel.selectedFeedbackIds.contains(feedback.id))

            Divider()
        }

        // Selection toggle
        Button {
            viewModel.toggleSelection(feedback.id)
        } label: {
            if viewModel.isSelected(feedback.id) {
                Label("Deselect", systemImage: "checkmark.circle.fill")
            } else {
                Label("Select for Merge", systemImage: "checkmark.circle")
            }
        }

        Divider()

        statusMenu(for: feedback)
        categoryMenu(for: feedback)
        Divider()
        Button(role: .destructive) {
            Task {
                await viewModel.deleteFeedback(id: feedback.id)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Kanban View

    private var kanbanView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(allowedStatuses, id: \.self) { status in
                    KanbanColumnView(
                        status: status,
                        feedbacks: viewModel.feedbacksByStatus[status] ?? [],
                        viewModel: viewModel,
                        project: project,
                        allowedStatuses: allowedStatuses,
                        feedbackToOpen: $feedbackToOpen
                    )
                }
            }
            .padding()
        }
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground))
        #endif
    }

    // MARK: - Context Menus

    private func statusMenu(for feedback: Feedback) -> some View {
        Menu {
            ForEach(allowedStatuses, id: \.self) { status in
                Button {
                    Task {
                        await viewModel.updateFeedbackStatus(id: feedback.id, status: status)
                    }
                } label: {
                    HStack {
                        Text(status.displayName)
                        Spacer()
                        if feedback.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Set Status", systemImage: "flag")
        }
    }

    private func categoryMenu(for feedback: Feedback) -> some View {
        Menu {
            ForEach(FeedbackCategory.allCases, id: \.self) { category in
                Button {
                    Task {
                        await viewModel.updateFeedbackCategory(id: feedback.id, category: category)
                    }
                } label: {
                    HStack {
                        Text(category.displayName)
                        Spacer()
                        if feedback.category == category {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Set Category", systemImage: "tag")
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Feedback", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("No feedback has been submitted for this project yet.")
        }
    }

    private var noResultsState: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No feedback matches your current filters.")
        } actions: {
            Button("Clear Filters") {
                viewModel.clearFilters()
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - List Row View

struct FeedbackListRowView: View {
    let feedback: Feedback
    var showMergeBadge: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                FeedbackStatusBadge(status: feedback.status)
                FeedbackCategoryBadge(category: feedback.category)
                MrrBadge(mrr: feedback.formattedMrr)
                if showMergeBadge {
                    MergeBadge(count: feedback.mergedCount)
                }
                if feedback.hasGitHubIssue {
                    GitHubBadge()
                }
                if feedback.hasClickUpTask {
                    ClickUpBadge()
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                    Text("\(feedback.voteCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
            }

            Text(feedback.title)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(feedback.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 12) {
                if let email = feedback.userEmail {
                    Label(email, systemImage: "person")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if feedback.commentCount > 0 {
                    Label("\(feedback.commentCount)", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let date = feedback.createdAt {
                    Text(date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Merge Badge

struct MergeBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.merge")
                .font(.caption2)
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.indigo.opacity(0.15))
        .foregroundStyle(.indigo)
        .clipShape(Capsule())
    }
}

// MARK: - GitHub Badge

struct GitHubBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.triangle.branch")
                .font(.caption2)
            Text("GitHub")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.1))
        .foregroundStyle(.primary.opacity(0.7))
        .clipShape(Capsule())
    }
}

// MARK: - ClickUp Badge

struct ClickUpBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "checklist")
                .font(.caption2)
            Text("ClickUp")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.purple.opacity(0.15))
        .foregroundStyle(.purple)
        .clipShape(Capsule())
    }
}

// MARK: - Kanban Column View

struct KanbanColumnView: View {
    let status: FeedbackStatus
    let feedbacks: [Feedback]
    @Bindable var viewModel: FeedbackViewModel
    let project: Project
    let allowedStatuses: [FeedbackStatus]
    @Binding var feedbackToOpen: Feedback?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column Header
            HStack {
                Image(systemName: status.icon)
                    .foregroundStyle(statusColor)
                Text(status.displayName)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(feedbacks.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.15))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.systemGray6))
            #endif

            Divider()

            // Cards
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(feedbacks) { feedback in
                        kanbanCard(for: feedback)
                    }
                }
                .padding(8)
            }
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .frame(width: 300)
        .dropDestination(for: String.self) { items, _ in
            guard let feedbackIdString = items.first,
                  let feedbackId = UUID(uuidString: feedbackIdString) else {
                return false
            }
            Task {
                await viewModel.updateFeedbackStatus(id: feedbackId, status: status)
            }
            return true
        }
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .approved: return .blue
        case .inProgress: return .orange
        case .testflight: return .cyan
        case .completed: return .green
        case .rejected: return .red
        }
    }

    @ViewBuilder
    private func kanbanCard(for feedback: Feedback) -> some View {
        #if os(macOS)
        // macOS: Single click selects, double click opens
        KanbanCardView(
            feedback: feedback,
            isSelected: viewModel.isSelected(feedback.id)
        )
        .onTapGesture(count: 2) {
            feedbackToOpen = feedback
        }
        .onTapGesture(count: 1) {
            viewModel.toggleSelection(feedback.id)
        }
        .draggable(feedback.id.uuidString)
        .contextMenu {
            Button {
                feedbackToOpen = feedback
            } label: {
                Label("Open", systemImage: "arrow.right.circle")
            }
            Divider()
            kanbanContextMenuItems(for: feedback)
        }
        #else
        // iOS: Single tap opens
        NavigationLink(value: feedback) {
            KanbanCardView(
                feedback: feedback,
                isSelected: viewModel.isSelected(feedback.id)
            )
        }
        .buttonStyle(.plain)
        .draggable(feedback.id.uuidString)
        .contextMenu {
            kanbanContextMenuItems(for: feedback)
        }
        #endif
    }

    @ViewBuilder
    private func kanbanContextMenuItems(for feedback: Feedback) -> some View {
        // GitHub options
        if project.isGitHubConfigured {
            if feedback.hasGitHubIssue {
                if let issueUrl = feedback.githubIssueUrl, let url = URL(string: issueUrl) {
                    Link(destination: url) {
                        Label("View GitHub Issue", systemImage: "link")
                    }
                }
            } else {
                Button {
                    Task {
                        await viewModel.createGitHubIssue(projectId: project.id, feedbackId: feedback.id)
                    }
                } label: {
                    Label("Push to GitHub", systemImage: "arrow.triangle.branch")
                }
            }
            Divider()
        }

        // ClickUp options
        if project.isClickUpConfigured {
            if feedback.hasClickUpTask {
                if let taskUrl = feedback.clickupTaskUrl, let url = URL(string: taskUrl) {
                    Link(destination: url) {
                        Label("View ClickUp Task", systemImage: "link")
                    }
                }
            } else {
                Button {
                    Task {
                        await viewModel.createClickUpTask(projectId: project.id, feedbackId: feedback.id)
                    }
                } label: {
                    Label("Push to ClickUp", systemImage: "checklist")
                }
            }
            Divider()
        }

        // Merge option
        if viewModel.selectedFeedbackIds.count >= 1 {
            Button {
                viewModel.startMerge(with: feedback)
            } label: {
                let count = viewModel.selectedFeedbackIds.contains(feedback.id)
                    ? viewModel.selectedFeedbackIds.count
                    : viewModel.selectedFeedbackIds.count + 1
                Label("Merge \(count) Items...", systemImage: "arrow.triangle.merge")
            }
            Divider()
        }

        // Selection toggle
        Button {
            viewModel.toggleSelection(feedback.id)
        } label: {
            if viewModel.isSelected(feedback.id) {
                Label("Deselect", systemImage: "checkmark.circle.fill")
            } else {
                Label("Select for Merge", systemImage: "checkmark.circle")
            }
        }

        Divider()

        // Status menu
        Menu {
            ForEach(allowedStatuses, id: \.self) { newStatus in
                Button {
                    Task {
                        await viewModel.updateFeedbackStatus(id: feedback.id, status: newStatus)
                    }
                } label: {
                    HStack {
                        Text(newStatus.displayName)
                        if feedback.status == newStatus {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Set Status", systemImage: "flag")
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await viewModel.deleteFeedback(id: feedback.id)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Kanban Card View

struct KanbanCardView: View {
    let feedback: Feedback
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FeedbackCategoryBadge(category: feedback.category)
                MrrBadge(mrr: feedback.formattedMrr)
                if feedback.hasMergedFeedback {
                    MergeBadge(count: feedback.mergedCount)
                }
                if feedback.hasGitHubIssue {
                    GitHubBadge()
                }
                if feedback.hasClickUpTask {
                    ClickUpBadge()
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                    Text("\(feedback.voteCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
            }

            Text(feedback.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(feedback.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack {
                if let email = feedback.userEmail {
                    Text(email)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                if feedback.commentCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left")
                            .font(.caption2)
                        Text("\(feedback.commentCount)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        #if os(macOS)
        .background(isSelected ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        #else
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Status Badge

struct FeedbackStatusBadge: View {
    let status: FeedbackStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.15))
        .foregroundStyle(statusColor)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .gray
        case .approved: return .blue
        case .inProgress: return .orange
        case .testflight: return .cyan
        case .completed: return .green
        case .rejected: return .red
        }
    }
}

// MARK: - Category Badge

struct FeedbackCategoryBadge: View {
    let category: FeedbackCategory

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.caption2)
            Text(category.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(categoryColor.opacity(0.15))
        .foregroundStyle(categoryColor)
        .clipShape(Capsule())
    }

    private var categoryColor: Color {
        switch category {
        case .featureRequest: return .purple
        case .bugReport: return .red
        case .improvement: return .teal
        case .other: return .gray
        }
    }
}

// MARK: - MRR Badge

struct MrrBadge: View {
    let mrr: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.caption2)
            Text(mrr)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.green.opacity(0.15))
        .foregroundStyle(.green)
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview("List View") {
    NavigationStack {
        FeedbackListView(
            project: Project(
                id: UUID(),
                name: "Test Project",
                apiKey: "test-key",
                description: nil,
                ownerId: UUID(),
                ownerEmail: nil,
                isArchived: false,
                archivedAt: nil,
                colorIndex: 0,
                feedbackCount: 0,
                memberCount: 1,
                createdAt: Date(),
                updatedAt: Date(),
                slackWebhookUrl: nil,
                slackNotifyNewFeedback: true,
                slackNotifyNewComments: true,
                slackNotifyStatusChanges: true,
                allowedStatuses: ["pending", "approved", "in_progress", "completed", "rejected"]
            ),
            viewModel: FeedbackViewModel()
        )
    }
}
