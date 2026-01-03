import SwiftUI
import OSLog

// MARK: - Users Dashboard View

struct UsersDashboardView: View {
    @Bindable var projectViewModel: ProjectViewModel
    @State private var userViewModel = SDKUserViewModel()
    @State private var selectedProject: ProjectListItem?

    private var groupedBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    var body: some View {
        dashboardContent
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    projectPicker
                }

                ToolbarItem(placement: .primaryAction) {
                    sortMenu
                }
            }
            .searchable(text: $userViewModel.searchText, prompt: "Search users...")
            .onChange(of: selectedProject) { _, newProject in
                Logger.view.info("UsersDashboardView: selectedProject changed to \(newProject?.name ?? "nil")")
                if let project = newProject {
                    Logger.view.info("UsersDashboardView: Triggering loadUsers for project: \(project.id.uuidString)")
                    Task {
                        await userViewModel.loadUsers(projectId: project.id)
                    }
                }
            }
            .task {
                Logger.view.info("UsersDashboardView: .task fired - projects count: \(self.projectViewModel.projects.count)")
                // Auto-select first project if none selected
                if selectedProject == nil, let first = projectViewModel.projects.first {
                    Logger.view.info("UsersDashboardView: Auto-selecting first project: \(first.name) (\(first.id.uuidString))")
                    selectedProject = first
                } else if selectedProject == nil {
                    Logger.view.warning("UsersDashboardView: No projects available to auto-select")
                } else {
                    Logger.view.debug("UsersDashboardView: Project already selected: \(self.selectedProject?.name ?? "nil")")
                }
            }
            #if os(iOS)
            .refreshable {
                Logger.view.info("UsersDashboardView: Pull to refresh triggered")
                if let project = selectedProject {
                    await userViewModel.loadUsers(projectId: project.id)
                }
            }
            #endif
            .alert("Error", isPresented: $userViewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(userViewModel.errorMessage ?? "An error occurred")
            }
            .onAppear {
                Logger.view.info("UsersDashboardView: onAppear - selectedProject: \(self.selectedProject?.name ?? "nil"), projects count: \(self.projectViewModel.projects.count)")
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

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(SDKUserViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    userViewModel.sortOrder = order
                } label: {
                    HStack {
                        Label(order.rawValue, systemImage: order.icon)
                        if userViewModel.sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        if selectedProject == nil {
            noProjectSelectedView
        } else if userViewModel.isLoading && userViewModel.users.isEmpty {
            ProgressView("Loading users...")
        } else if userViewModel.users.isEmpty {
            emptyUsersView
        } else if userViewModel.filteredUsers.isEmpty {
            noResultsView
        } else {
            usersListContent
        }
    }

    // MARK: - Users List Content

    private var usersListContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats Section
                if let stats = userViewModel.stats {
                    UserStatsView(stats: stats)
                }

                // Users Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Users (\(userViewModel.filteredUsers.count))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(userViewModel.filteredUsers) { user in
                            UserDashboardRowView(user: user)
                            if user.id != userViewModel.filteredUsers.last?.id {
                                Divider()
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                }
            }
            .padding()
            #if os(macOS)
            .frame(maxWidth: 800, alignment: .center)
            #endif
        }
        #if os(macOS)
        .frame(maxWidth: .infinity)
        #endif
        .background(groupedBackgroundColor)
    }

    // MARK: - Empty States

    private var noProjectSelectedView: some View {
        ContentUnavailableView {
            Label("No Project Selected", systemImage: "folder")
        } description: {
            Text("Select a project from the dropdown to view its users.")
        }
    }

    private var emptyUsersView: some View {
        ContentUnavailableView {
            Label("No Users", systemImage: "person.2")
        } description: {
            Text("No users have interacted with this project yet.")
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No users match your search.")
        } actions: {
            Button("Clear Search") {
                userViewModel.searchText = ""
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - User Stats View

struct UserStatsView: View {
    let stats: SDKUserStats

    #if os(macOS)
    private let columns = [
        GridItem(.flexible(minimum: 140, maximum: 180)),
        GridItem(.flexible(minimum: 140, maximum: 180)),
        GridItem(.flexible(minimum: 140, maximum: 180)),
        GridItem(.flexible(minimum: 140, maximum: 180))
    ]
    #else
    private let columns = [
        GridItem(.flexible(minimum: 100, maximum: 180)),
        GridItem(.flexible(minimum: 100, maximum: 180))
    ]
    #endif

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            UserStatCard(
                icon: "person.2.fill",
                iconColor: .blue,
                title: "Total Users",
                value: "\(stats.totalUsers)"
            )

            UserStatCard(
                icon: "dollarsign.circle.fill",
                iconColor: .green,
                title: "Total MRR",
                value: stats.formattedTotalMRR
            )

            UserStatCard(
                icon: "person.crop.circle.badge.checkmark",
                iconColor: .purple,
                title: "Paying Users",
                value: "\(stats.usersWithMrr)"
            )

            UserStatCard(
                icon: "chart.bar.fill",
                iconColor: .orange,
                title: "Avg MRR",
                value: stats.formattedAverageMRR
            )
        }
        .padding(.vertical, 8)
    }
}

// MARK: - User Stat Card

struct UserStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - User Dashboard Row View

struct UserDashboardRowView: View {
    let user: SDKUser

    private var formattedMRR: String {
        guard let mrr = user.mrr, mrr > 0 else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: mrr)) ?? "$\(mrr)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // User Type Icon
            Image(systemName: user.userType.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(userTypeColor, in: RoundedRectangle(cornerRadius: 8))

            // User Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayUserId)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(user.userType.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(userTypeColor.opacity(0.15))
                        .foregroundStyle(userTypeColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    Label("\(user.feedbackCount)", systemImage: "bubble.left")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(user.voteCount)", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let lastSeen = user.lastSeenAt {
                        Text(lastSeen, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // MRR Badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedMRR)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(user.mrr ?? 0 > 0 ? .green : .secondary)

                Text("MRR")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var userTypeColor: Color {
        switch user.userType {
        case .iCloud: return .blue
        case .local: return .gray
        case .custom: return .purple
        }
    }
}

// MARK: - Preview

#Preview("Users Dashboard") {
    NavigationStack {
        UsersDashboardView(projectViewModel: ProjectViewModel())
    }
}
