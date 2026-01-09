import SwiftUI

// MARK: - View Mode

enum ProjectViewMode: String, CaseIterable {
    case list
    case table
    case grid

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .table: return "tablecells"
        case .grid: return "square.grid.2x2"
        }
    }

    var label: String {
        switch self {
        case .list: return "List"
        case .table: return "Table"
        case .grid: return "Grid"
        }
    }
}

// MARK: - Main View

struct ProjectListView: View {
    @Bindable var viewModel: ProjectViewModel
    @State private var showingCreateSheet = false
    @State private var showingAcceptInviteSheet = false
    @State private var showPaywall = false
    @State private var subscriptionService = SubscriptionService.shared
    @AppStorage("projectViewMode") private var viewMode: ProjectViewMode = .list
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Number of projects owned by the current user
    private var ownedProjectCount: Int {
        viewModel.projects.filter { $0.isOwner }.count
    }

    /// Whether the user can create a new project based on their subscription
    private var canCreateProject: Bool {
        guard let maxProjects = subscriptionService.currentTier.maxProjects else {
            return true // Unlimited
        }
        return ownedProjectCount < maxProjects
    }

    var body: some View {
        projectListContent
    }

    @ViewBuilder
    private var projectListContent: some View {
        Group {
            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView("Loading projects...")
            } else if viewModel.projects.isEmpty {
                emptyState
            } else {
                projectsView
            }
        }
        .navigationTitle("Projects")
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

            // Project count indicator
            if let maxProjects = subscriptionService.currentTier.maxProjects {
                ToolbarItem(placement: .automatic) {
                    Text("\(ownedProjectCount)/\(maxProjects)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        #if os(iOS)
                        .background(Color(UIColor.secondarySystemBackground), in: Capsule())
                        #else
                        .background(Color(NSColor.windowBackgroundColor), in: Capsule())
                        #endif
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        if canCreateProject {
                            showingCreateSheet = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Label("New Project", systemImage: "folder.badge.plus")
                    }

                    Button {
                        showingAcceptInviteSheet = true
                    } label: {
                        Label("Enter Invite Code", systemImage: "envelope.open")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProjectView(viewModel: viewModel) {
                showingCreateSheet = false
            }
        }
        .sheet(isPresented: $showingAcceptInviteSheet) {
            AcceptInviteView(viewModel: viewModel)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        #if os(iOS)
        .refreshable {
            await viewModel.loadProjects()
        }
        #endif
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        Picker("View Mode", selection: $viewMode) {
            ForEach(ProjectViewMode.allCases, id: \.self) { mode in
                Label(mode.label, systemImage: mode.icon)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        #if os(iOS)
        .frame(width: horizontalSizeClass == .compact ? 120 : 150)
        #else
        .frame(width: 150)
        #endif
    }

    // MARK: - Projects View

    @ViewBuilder
    private var projectsView: some View {
        switch viewMode {
        case .list:
            listView
        case .table:
            tableView
        case .grid:
            gridView
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(viewModel.projects) { project in
                NavigationLink(value: project) {
                    ProjectListRowView(project: project)
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: ProjectListItem.self) { project in
            ProjectDetailView(projectId: project.id, viewModel: viewModel)
        }
    }

    // MARK: - Table View

    private var tableView: some View {
        List {
            ForEach(viewModel.projects) { project in
                NavigationLink(value: project) {
                    ProjectTableRowView(project: project)
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset(alternatesRowBackgrounds: true))
        #else
        .listStyle(.plain)
        #endif
        .navigationDestination(for: ProjectListItem.self) { project in
            ProjectDetailView(projectId: project.id, viewModel: viewModel)
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(viewModel.projects) { project in
                    NavigationLink(value: project) {
                        ProjectCardView(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        #if os(macOS)
        .background(Color(nsColor: .windowBackgroundColor))
        #else
        .background(Color(.systemGroupedBackground))
        #endif
        .navigationDestination(for: ProjectListItem.self) { project in
            ProjectDetailView(projectId: project.id, viewModel: viewModel)
        }
    }

    private var gridColumns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)]
        #else
        if horizontalSizeClass == .compact {
            [GridItem(.flexible(), spacing: 16)]
        } else {
            [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]
        }
        #endif
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Projects", systemImage: "folder")
        } description: {
            Text("Create your first project or join an existing one with an invite code")
        } actions: {
            HStack(spacing: 12) {
                Button("Create Project") {
                    showingCreateSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("Enter Invite Code") {
                    showingAcceptInviteSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - List Row View (Compact)

struct ProjectListRowView: View {
    let project: ProjectListItem

    var body: some View {
        HStack(spacing: 12) {
            // Project Icon
            ProjectIconView(
                name: project.name,
                isArchived: project.isArchived,
                colorIndex: project.colorIndex,
                size: 44
            )

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if project.isArchived {
                        archivedBadge
                    }
                }

                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Label("\(project.feedbackCount)", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    roleBadge
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var archivedBadge: some View {
        Text("Archived")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.15))
            .foregroundStyle(.orange)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var roleBadge: some View {
        if project.isOwner {
            Label("Owner", systemImage: "crown.fill")
                .font(.caption)
                .foregroundStyle(.blue)
        } else if let role = project.role {
            Text(role.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Table Row View (Detailed)

struct ProjectTableRowView: View {
    let project: ProjectListItem
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        #if os(macOS)
        return false
        #else
        return horizontalSizeClass == .compact
        #endif
    }

    var body: some View {
        HStack(spacing: 16) {
            // Project Icon
            ProjectIconView(
                name: project.name,
                isArchived: project.isArchived,
                colorIndex: project.colorIndex,
                size: 40
            )

            // Name Column
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if project.isArchived {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let description = project.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            if !isCompact {
                // Feedback Count Column
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(project.feedbackCount)")
                        .font(.subheadline)
                        .monospacedDigit()
                }
                .frame(width: 60, alignment: .trailing)

                // Role Column
                roleView
                    .frame(width: 80, alignment: .center)

                // Date Column
                if let createdAt = project.createdAt {
                    Text(createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .trailing)
                }
            } else {
                // Compact: Just show feedback count
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption2)
                    Text("\(project.feedbackCount)")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var roleView: some View {
        if project.isOwner {
            Label("Owner", systemImage: "crown.fill")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
        } else if let role = project.role {
            Text(role.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(roleColor.opacity(0.1))
                .foregroundStyle(roleColor)
                .clipShape(Capsule())
        }
    }

    private var roleColor: Color {
        switch project.role {
        case .admin: return .purple
        case .member: return .green
        case .viewer: return .gray
        case .none: return .gray
        }
    }
}

// MARK: - Card View

struct ProjectCardView: View {
    let project: ProjectListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ProjectIconView(
                    name: project.name,
                    isArchived: project.isArchived,
                    colorIndex: project.colorIndex,
                    size: 48
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if project.isOwner {
                            Label("Owner", systemImage: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else if let role = project.role {
                            Text(role.displayName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if project.isArchived {
                            Text("Archived")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
            .padding()

            Divider()
                .padding(.horizontal)

            // Description
            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else {
                Text("No description")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Spacer(minLength: 0)

            // Footer Stats
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(.blue)
                    Text("\(project.feedbackCount)")
                        .fontWeight(.semibold)
                    Text("Feedback")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let createdAt = project.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.systemGray6))
            #endif
        }
        #if os(macOS)
        .background(Color(nsColor: .textBackgroundColor))
        #else
        .background(Color(.systemBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Project Icon View

struct ProjectIconView: View {
    let name: String
    let isArchived: Bool
    let colorIndex: Int
    let size: CGFloat

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private static let gradients: [(Color, Color)] = [
        (.blue, .purple),
        (.green, .teal),
        (.orange, .red),
        (.pink, .purple),
        (.indigo, .blue),
        (.teal, .cyan),
        (.purple, .pink),
        (.mint, .green)
    ]

    private var gradient: LinearGradient {
        if isArchived {
            return LinearGradient(
                colors: [.gray, .gray.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        let safeIndex = abs(colorIndex) % Self.gradients.count
        let colors = Self.gradients[safeIndex]

        return LinearGradient(
            colors: [colors.0, colors.1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            gradient

            if isArchived {
                Image(systemName: "archivebox.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}

// MARK: - Preview

#Preview("List View") {
    NavigationStack {
        ProjectListView(viewModel: ProjectViewModel())
    }
}
