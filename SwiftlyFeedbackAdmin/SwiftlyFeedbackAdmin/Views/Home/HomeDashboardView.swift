import SwiftUI
import OSLog

// MARK: - Home Dashboard View

struct HomeDashboardView: View {
    @Bindable var viewModel: HomeDashboardViewModel

    private var groupedBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    var body: some View {
        dashboardContent
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    projectPicker
                }
            }
            .task {
                Logger.view.info("HomeDashboardView: .task fired")
                // Small delay to let the view settle and avoid cancellation during navigation setup
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else {
                    Logger.view.info("HomeDashboardView: .task cancelled during delay")
                    return
                }
                await viewModel.loadDashboard()
            }
            #if os(iOS)
            .refreshable {
                Logger.view.info("HomeDashboardView: Pull to refresh triggered")
                await viewModel.refreshDashboard()
            }
            #endif
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
    }

    // MARK: - Project Picker

    private var projectPicker: some View {
        Menu {
            Button {
                viewModel.selectProject(nil)
            } label: {
                HStack {
                    Text("All Projects")
                    if viewModel.selectedProjectId == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }

            if let dashboard = viewModel.dashboard, !dashboard.projectStats.isEmpty {
                Divider()

                ForEach(dashboard.projectStats) { project in
                    Button {
                        viewModel.selectProject(project.id)
                    } label: {
                        HStack {
                            Text(project.name)
                            if project.isArchived {
                                Image(systemName: "archivebox")
                            }
                            if viewModel.selectedProjectId == project.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let selectedId = viewModel.selectedProjectId,
                   let project = viewModel.dashboard?.projectStats.first(where: { $0.id == selectedId }) {
                    ProjectIconView(
                        name: project.name,
                        isArchived: project.isArchived,
                        size: 24
                    )
                    Text(project.name)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "house.fill")
                        .foregroundStyle(.blue)
                    Text("All Projects")
                        .fontWeight(.medium)
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

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        dashboardListContent
            .overlay {
                if viewModel.isLoading && viewModel.dashboard == nil {
                    ProgressView("Loading dashboard...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
    }

    // MARK: - Dashboard List Content

    private var dashboardListContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // KPI Stats Section
                HomeStatsView(stats: viewModel.displayStats)

                // Feedback Status Breakdown
                FeedbackStatusBreakdownView(feedbackByStatus: viewModel.displayStats.feedbackByStatus)

                // Projects Section (only show when "All Projects" is selected)
                if viewModel.selectedProjectId == nil {
                    projectsSection
                }
            }
            .padding()
            #if os(macOS)
            .frame(maxWidth: 900, alignment: .center)
            #endif
        }
        #if os(macOS)
        .frame(maxWidth: .infinity)
        #endif
        .background(groupedBackgroundColor)
    }

    // MARK: - Projects Section

    @ViewBuilder
    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Projects (\(viewModel.filteredProjectStats.count))")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if viewModel.filteredProjectStats.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No projects yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.filteredProjectStats) { project in
                        ProjectStatsRowView(project: project)
                        if project.id != viewModel.filteredProjectStats.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding()
                .background(.background, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Home Stats View

struct HomeStatsView: View {
    let stats: HomeDashboardViewModel.DisplayStats

    #if os(macOS)
    private let columns = [
        GridItem(.flexible(minimum: 120, maximum: 160)),
        GridItem(.flexible(minimum: 120, maximum: 160)),
        GridItem(.flexible(minimum: 120, maximum: 160)),
        GridItem(.flexible(minimum: 120, maximum: 160)),
        GridItem(.flexible(minimum: 120, maximum: 160)),
        GridItem(.flexible(minimum: 120, maximum: 160))
    ]
    #else
    private let columns = [
        GridItem(.flexible(minimum: 100, maximum: 180)),
        GridItem(.flexible(minimum: 100, maximum: 180)),
        GridItem(.flexible(minimum: 100, maximum: 180))
    ]
    #endif

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            if let totalProjects = stats.totalProjects {
                HomeStatCard(
                    icon: "folder.fill",
                    iconColor: .blue,
                    title: "Projects",
                    value: "\(totalProjects)"
                )
            }

            HomeStatCard(
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: .purple,
                title: "Feedback",
                value: "\(stats.totalFeedback)"
            )

            HomeStatCard(
                icon: "person.2.fill",
                iconColor: .green,
                title: "Users",
                value: "\(stats.totalUsers)"
            )

            HomeStatCard(
                icon: "text.bubble.fill",
                iconColor: .orange,
                title: "Comments",
                value: "\(stats.totalComments)"
            )

            HomeStatCard(
                icon: "arrow.up.circle.fill",
                iconColor: .pink,
                title: "Votes",
                value: "\(stats.totalVotes)"
            )
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Home Stat Card

struct HomeStatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
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
        .frame(height: 90)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Feedback Status Breakdown View

struct FeedbackStatusBreakdownView: View {
    let feedbackByStatus: FeedbackByStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feedback by Status")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                StatusCard(title: "Pending", count: feedbackByStatus.pending, color: .gray)
                StatusCard(title: "Approved", count: feedbackByStatus.approved, color: .blue)
                StatusCard(title: "In Progress", count: feedbackByStatus.inProgress, color: .orange)
                StatusCard(title: "Completed", count: feedbackByStatus.completed, color: .green)
                StatusCard(title: "Rejected", count: feedbackByStatus.rejected, color: .red)
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Project Stats Row View

struct ProjectStatsRowView: View {
    let project: ProjectStats

    var body: some View {
        HStack(spacing: 12) {
            // Project Icon
            ProjectIconView(
                name: project.name,
                isArchived: project.isArchived,
                size: 44
            )

            // Project Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

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

                HStack(spacing: 16) {
                    Label("\(project.feedbackCount)", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(project.userCount)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(project.commentCount)", systemImage: "text.bubble")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("\(project.voteCount)", systemImage: "arrow.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status breakdown mini-view
            HStack(spacing: 8) {
                MiniStatusBadge(count: project.feedbackByStatus.pending, color: .gray, label: "P")
                MiniStatusBadge(count: project.feedbackByStatus.inProgress, color: .orange, label: "IP")
                MiniStatusBadge(count: project.feedbackByStatus.completed, color: .green, label: "C")
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Mini Status Badge

struct MiniStatusBadge: View {
    let count: Int
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(width: 28)
    }
}

// MARK: - Preview

#Preview("Home Dashboard") {
    NavigationStack {
        HomeDashboardView(viewModel: HomeDashboardViewModel())
    }
}
