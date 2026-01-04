import SwiftUI

// MARK: - View Mode

enum DashboardViewMode: String, CaseIterable {
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

// MARK: - Main Dashboard View

struct FeedbackDashboardView: View {
    @Bindable var projectViewModel: ProjectViewModel
    @State private var feedbackViewModel = FeedbackViewModel()
    @State private var selectedProject: ProjectListItem?
    @AppStorage("dashboardViewMode") private var viewMode: DashboardViewMode = .kanban
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        dashboardContent
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    projectPicker
                }

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
            .searchable(text: $feedbackViewModel.searchText, prompt: "Search feedback...")
            .onChange(of: selectedProject) { _, newProject in
                if let project = newProject {
                    Task {
                        await loadFeedbackForProject(project)
                    }
                }
            }
            .task {
                // Auto-select first project if none selected
                if selectedProject == nil, let first = projectViewModel.projects.first {
                    selectedProject = first
                }
            }
            #if os(iOS)
            .refreshable {
                if let project = selectedProject {
                    await loadFeedbackForProject(project)
                }
            }
            #endif
            .alert("Error", isPresented: $feedbackViewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(feedbackViewModel.errorMessage ?? "An error occurred")
            }
            .navigationDestination(for: Feedback.self) { feedback in
                if let project = selectedProject {
                    FeedbackDetailView(
                        feedback: feedback,
                        apiKey: projectApiKey(for: project),
                        viewModel: feedbackViewModel
                    )
                }
            }
    }

    // MARK: - Project Picker

    private var projectPicker: some View {
        Menu {
            if projectViewModel.projects.isEmpty {
                Text("No projects available")
            } else {
                ForEach(projectViewModel.projects) { project in
                    Button {
                        selectedProject = project
                    } label: {
                        HStack {
                            Text(project.name)
                            if selectedProject?.id == project.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let project = selectedProject {
                    ProjectIconView(
                        name: project.name,
                        isArchived: project.isArchived,
                        colorIndex: project.colorIndex,
                        size: 24
                    )
                    Text(project.name)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "folder")
                    Text("Select Project")
                }
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.secondarySystemBackground))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(DashboardViewMode.allCases, id: \.self) { mode in
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

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            // Sort menu
            Menu {
                ForEach(FeedbackSortOption.allCases, id: \.self) { option in
                    Button {
                        feedbackViewModel.sortOption = option
                    } label: {
                        HStack {
                            Label(option.displayName, systemImage: option.icon)
                            Spacer()
                            if feedbackViewModel.sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort by", systemImage: "arrow.up.arrow.down")
            }

            Divider()

            Menu {
                Button {
                    feedbackViewModel.statusFilter = nil
                } label: {
                    HStack {
                        Text("All Statuses")
                        Spacer()
                        if feedbackViewModel.statusFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(FeedbackStatus.allCases, id: \.self) { status in
                    Button {
                        feedbackViewModel.statusFilter = status
                    } label: {
                        HStack {
                            Text(status.displayName)
                            Spacer()
                            if feedbackViewModel.statusFilter == status {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Status", systemImage: "flag")
            }

            Menu {
                Button {
                    feedbackViewModel.categoryFilter = nil
                } label: {
                    HStack {
                        Text("All Categories")
                        Spacer()
                        if feedbackViewModel.categoryFilter == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Divider()

                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                    Button {
                        feedbackViewModel.categoryFilter = category
                    } label: {
                        HStack {
                            Text(category.displayName)
                            Spacer()
                            if feedbackViewModel.categoryFilter == category {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Category", systemImage: "tag")
            }

            if feedbackViewModel.statusFilter != nil || feedbackViewModel.categoryFilter != nil || feedbackViewModel.sortOption != .votes {
                Divider()

                Button(role: .destructive) {
                    feedbackViewModel.clearFilters()
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
        if feedbackViewModel.statusFilter != nil { count += 1 }
        if feedbackViewModel.categoryFilter != nil { count += 1 }
        if feedbackViewModel.sortOption != .votes { count += 1 }
        return count
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        if selectedProject == nil {
            noProjectSelectedView
        } else if feedbackViewModel.isLoading && feedbackViewModel.feedbacks.isEmpty {
            ProgressView("Loading feedback...")
        } else if feedbackViewModel.feedbacks.isEmpty {
            emptyFeedbackView
        } else if feedbackViewModel.filteredFeedbacks.isEmpty {
            noResultsView
        } else {
            switch viewMode {
            case .list:
                listView
            case .kanban:
                kanbanView
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(feedbackViewModel.filteredFeedbacks) { feedback in
                NavigationLink(value: feedback) {
                    FeedbackListRowView(feedback: feedback)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task {
                            await feedbackViewModel.deleteFeedback(id: feedback.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    statusMenu(for: feedback)
                    categoryMenu(for: feedback)
                    Divider()
                    Button(role: .destructive) {
                        Task {
                            await feedbackViewModel.deleteFeedback(id: feedback.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Kanban View

    private var kanbanView: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(FeedbackStatus.allCases, id: \.self) { status in
                    DashboardKanbanColumnView(
                        status: status,
                        feedbacks: feedbackViewModel.feedbacksByStatus[status] ?? [],
                        viewModel: feedbackViewModel,
                        apiKey: selectedProject.map { projectApiKey(for: $0) } ?? ""
                    )
                }
            }
            .padding()
        }
        .scrollIndicators(.visible)
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        #endif
    }

    // MARK: - Context Menus

    private func statusMenu(for feedback: Feedback) -> some View {
        Menu {
            ForEach(FeedbackStatus.allCases, id: \.self) { status in
                Button {
                    Task {
                        await feedbackViewModel.updateFeedbackStatus(id: feedback.id, status: status)
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
                        await feedbackViewModel.updateFeedbackCategory(id: feedback.id, category: category)
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

    private var noProjectSelectedView: some View {
        ContentUnavailableView {
            Label("No Project Selected", systemImage: "folder")
        } description: {
            Text("Select a project from the dropdown to view its feedback.")
        }
    }

    private var emptyFeedbackView: some View {
        ContentUnavailableView {
            Label("No Feedback", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("No feedback has been submitted for this project yet.")
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No feedback matches your current filters.")
        } actions: {
            Button("Clear Filters") {
                feedbackViewModel.clearFilters()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Helpers

    private func loadFeedbackForProject(_ project: ProjectListItem) async {
        // We need to fetch the full project to get the API key
        await projectViewModel.loadProject(id: project.id)
        if let fullProject = projectViewModel.selectedProject {
            await feedbackViewModel.loadFeedbacks(projectId: project.id, apiKey: fullProject.apiKey)
        }
    }

    private func projectApiKey(for project: ProjectListItem) -> String {
        // Return the API key from the selected project details
        projectViewModel.selectedProject?.apiKey ?? ""
    }
}

// MARK: - Dashboard Kanban Column View

struct DashboardKanbanColumnView: View {
    let status: FeedbackStatus
    let feedbacks: [Feedback]
    @Bindable var viewModel: FeedbackViewModel
    let apiKey: String

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
                        NavigationLink(value: feedback) {
                            DashboardKanbanCardView(
                                feedback: feedback,
                                viewModel: viewModel
                            )
                        }
                        .buttonStyle(.plain)
                        .draggable(feedback.id.uuidString)
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
        case .completed: return .green
        case .rejected: return .red
        }
    }
}

// MARK: - Dashboard Kanban Card View

struct DashboardKanbanCardView: View {
    let feedback: Feedback
    @Bindable var viewModel: FeedbackViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                FeedbackCategoryBadge(category: feedback.category)
                MrrBadge(mrr: feedback.formattedMrr)
                Spacer()
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
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.secondarySystemGroupedBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Preview

#Preview("Feedback Dashboard") {
    FeedbackDashboardView(projectViewModel: ProjectViewModel())
}
