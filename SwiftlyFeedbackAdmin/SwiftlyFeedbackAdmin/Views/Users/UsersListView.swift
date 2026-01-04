import SwiftUI

struct UsersListView: View {
    let project: Project
    @State private var viewModel = SDKUserViewModel()

    var body: some View {
        List {
            // Stats Section
            if let stats = viewModel.stats {
                Section {
                    StatsGridView(stats: stats)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Users Section
            Section {
                if viewModel.isLoading && viewModel.users.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView("Loading users...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } else if viewModel.filteredUsers.isEmpty && !viewModel.users.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("No users match your search.")
                    }
                    .listRowBackground(Color.clear)
                } else if viewModel.users.isEmpty {
                    ContentUnavailableView {
                        Label("No Users", systemImage: "person.2")
                    } description: {
                        Text("No users have interacted with this project yet.")
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.filteredUsers) { user in
                        UserRowView(user: user)
                    }
                }
            } header: {
                if !viewModel.users.isEmpty {
                    Text("Users (\(viewModel.filteredUsers.count))")
                }
            }
        }
        #if os(macOS)
        .listStyle(.inset)
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("Users")
        .searchable(text: $viewModel.searchText, prompt: "Search users...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
        }
        .task {
            await viewModel.loadUsers(projectId: project.id)
        }
        #if os(iOS)
        .refreshable {
            await viewModel.refreshUsers()
        }
        #endif
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(SDKUserViewModel.SortOrder.allCases, id: \.self) { order in
                Button {
                    viewModel.sortOrder = order
                } label: {
                    Label(order.rawValue, systemImage: order.icon)
                }
                .disabled(viewModel.sortOrder == order)
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }
}

// MARK: - Stats Grid View

struct StatsGridView: View {
    let stats: SDKUserStats

    private let columns = [
        GridItem(.flexible(minimum: 120, maximum: 200)),
        GridItem(.flexible(minimum: 120, maximum: 200))
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            StatCard(
                icon: "person.2.fill",
                iconColor: .blue,
                title: "Total Users",
                value: "\(stats.totalUsers)"
            )

            StatCard(
                icon: "dollarsign.circle.fill",
                iconColor: .green,
                title: "Total MRR",
                value: stats.formattedTotalMRR
            )

            StatCard(
                icon: "person.crop.circle.badge.checkmark",
                iconColor: .purple,
                title: "Paying Users",
                value: "\(stats.usersWithMrr)"
            )

            StatCard(
                icon: "chart.bar.fill",
                iconColor: .orange,
                title: "Avg MRR",
                value: stats.formattedAverageMRR
            )
        }
        .padding(.vertical, 8)
    }
}

// MARK: - User Row View

struct UserRowView: View {
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
                .frame(width: 32, height: 32)
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

#Preview("Users List") {
    NavigationStack {
        UsersListView(
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
            )
        )
    }
}
