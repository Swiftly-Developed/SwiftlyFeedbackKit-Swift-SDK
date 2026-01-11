import SwiftUI

struct ProjectDetailView: View {
    let projectId: UUID
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingDeleteAlert = false
    @State private var showingRegenerateAlert = false
    @State private var showingArchiveAlert = false
    @State private var showingMembersSheet = false
    @State private var showingEditSheet = false
    @State private var showingSlackSheet = false
    @State private var showingStatusSheet = false
    @State private var showingGitHubSheet = false
    @State private var showingClickUpSheet = false
    @State private var showingNotionSheet = false
    @State private var showingMondaySheet = false
    @State private var showingLinearSheet = false
    @State private var copiedToClipboard = false
    @State private var showingPaywall = false
    @State private var paywallRequiredTier: SubscriptionTier = .pro
    @State private var subscriptionService = SubscriptionService.shared

    private var isCompact: Bool {
        #if os(macOS)
        return false
        #else
        return horizontalSizeClass == .compact
        #endif
    }

    private var groupedBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    var body: some View {
        Group {
            if viewModel.isLoadingDetail {
                loadingView
            } else if let project = viewModel.selectedProject {
                projectContent(project)
            } else {
                ContentUnavailableView(
                    "Project Not Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text("The project could not be loaded")
                )
            }
        }
        .navigationTitle(viewModel.selectedProject?.name ?? "Project")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            if let project = viewModel.selectedProject {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Edit Project", systemImage: "pencil")
                        }

                        Button {
                            if subscriptionService.meetsRequirement(.team) {
                                showingMembersSheet = true
                            } else {
                                paywallRequiredTier = .team
                                showingPaywall = true
                            }
                        } label: {
                            Label("Manage Members", systemImage: "person.2")
                                .tierBadge(.team)
                        }

                        Button {
                            if subscriptionService.meetsRequirement(.pro) {
                                showingStatusSheet = true
                            } else {
                                paywallRequiredTier = .pro
                                showingPaywall = true
                            }
                        } label: {
                            Label("Status Settings", systemImage: "list.bullet.clipboard")
                                .tierBadge(.pro)
                        }

                        Divider()

                        Menu {
                            Button {
                                if subscriptionService.meetsRequirement(.pro) {
                                    showingSlackSheet = true
                                } else {
                                    paywallRequiredTier = .pro
                                    showingPaywall = true
                                }
                            } label: {
                                Label("Slack", systemImage: "number")
                                    .tierBadge(.pro)
                            }

                            Button {
                                if subscriptionService.meetsRequirement(.pro) {
                                    showingGitHubSheet = true
                                } else {
                                    paywallRequiredTier = .pro
                                    showingPaywall = true
                                }
                            } label: {
                                Label("GitHub", systemImage: "arrow.triangle.branch")
                                    .tierBadge(.pro)
                            }

                            Button {
                                if subscriptionService.meetsRequirement(.pro) {
                                    showingClickUpSheet = true
                                } else {
                                    paywallRequiredTier = .pro
                                    showingPaywall = true
                                }
                            } label: {
                                Label("ClickUp", systemImage: "checklist")
                                    .tierBadge(.pro)
                            }

                            Button {
                                if subscriptionService.meetsRequirement(.pro) {
                                    showingNotionSheet = true
                                } else {
                                    paywallRequiredTier = .pro
                                    showingPaywall = true
                                }
                            } label: {
                                Label("Notion", systemImage: "doc.text")
                                    .tierBadge(.pro)
                            }

                            Button {
                                if subscriptionService.meetsRequirement(.pro) {
                                    showingMondaySheet = true
                                } else {
                                    paywallRequiredTier = .pro
                                    showingPaywall = true
                                }
                            } label: {
                                Label("Monday.com", systemImage: "calendar")
                                    .tierBadge(.pro)
                            }

                            Button {
                                if subscriptionService.meetsRequirement(.pro) {
                                    showingLinearSheet = true
                                } else {
                                    paywallRequiredTier = .pro
                                    showingPaywall = true
                                }
                            } label: {
                                Label("Linear", systemImage: "arrow.triangle.branch")
                                    .tierBadge(.pro)
                            }
                        } label: {
                            Label("Integrations", systemImage: "puzzlepiece.extension")
                        }

                        Divider()

                        Button {
                            showingArchiveAlert = true
                        } label: {
                            if project.isArchived {
                                Label("Unarchive Project", systemImage: "archivebox")
                            } else {
                                Label("Archive Project", systemImage: "archivebox")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Project", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadProject(id: projectId)
        }
        .alert("Delete Project", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteProject(id: projectId) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this project? This will also delete all feedback and cannot be undone.")
        }
        .alert("Regenerate API Key", isPresented: $showingRegenerateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Regenerate", role: .destructive) {
                Task {
                    await viewModel.regenerateApiKey(id: projectId)
                }
            }
        } message: {
            Text("This will invalidate the current API key. Any apps using the old key will stop working.")
        }
        .alert(viewModel.selectedProject?.isArchived == true ? "Unarchive Project" : "Archive Project", isPresented: $showingArchiveAlert) {
            Button("Cancel", role: .cancel) {}
            Button(viewModel.selectedProject?.isArchived == true ? "Unarchive" : "Archive") {
                Task {
                    if viewModel.selectedProject?.isArchived == true {
                        await viewModel.unarchiveProject(id: projectId)
                    } else {
                        await viewModel.archiveProject(id: projectId)
                    }
                }
            }
        } message: {
            if viewModel.selectedProject?.isArchived == true {
                Text("This will allow new feedback to be submitted again.")
            } else {
                Text("Archived projects cannot receive new feedback, votes, or comments. Existing data will still be readable.")
            }
        }
        .sheet(isPresented: $showingMembersSheet) {
            ProjectMembersView(projectId: projectId, viewModel: viewModel)
                #if os(macOS)
                .frame(minWidth: 400, minHeight: 300)
                #endif
        }
        .sheet(isPresented: $showingEditSheet) {
            if let project = viewModel.selectedProject {
                EditProjectView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 400, minHeight: 200)
                    #endif
            }
        }
        .sheet(isPresented: $showingSlackSheet) {
            if let project = viewModel.selectedProject {
                SlackSettingsView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 450, minHeight: 350)
                    #endif
            }
        }
        .sheet(isPresented: $showingStatusSheet) {
            if let project = viewModel.selectedProject {
                StatusSettingsView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 400, minHeight: 400)
                    #endif
            }
        }
        .sheet(isPresented: $showingGitHubSheet) {
            if let project = viewModel.selectedProject {
                GitHubSettingsView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 450, minHeight: 450)
                    #endif
            }
        }
        .sheet(isPresented: $showingClickUpSheet) {
            if let project = viewModel.selectedProject {
                ClickUpSettingsView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 500, minHeight: 500)
                    #endif
            }
        }
        .sheet(isPresented: $showingNotionSheet) {
            if let project = viewModel.selectedProject {
                NotionSettingsView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 500, minHeight: 500)
                    #endif
            }
        }
        .sheet(isPresented: $showingMondaySheet) {
            if let project = viewModel.selectedProject {
                MondaySettingsView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 500, minHeight: 500)
                    #endif
            }
        }
        .sheet(isPresented: $showingLinearSheet) {
            if let project = viewModel.selectedProject {
                LinearSettingsView(project: project, viewModel: viewModel)
                    #if os(macOS)
                    .frame(minWidth: 500, minHeight: 500)
                    #endif
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(requiredTier: paywallRequiredTier)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Loading project...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Project Content

    @ViewBuilder
    private func projectContent(_ project: Project) -> some View {
        ScrollView {
            VStack(spacing: isCompact ? 16 : 20) {
                // Archive Banner
                if project.isArchived {
                    archiveBanner
                }

                // API Key Card
                apiKeyCard(project)

                // Stats Grid
                statsGrid(project)

                // Integrations Card
                if project.hasAnyIntegration {
                    integrationsCard(project)
                }

                // Description Card
                if let description = project.description, !description.isEmpty {
                    descriptionCard(description)
                }

                // Quick Actions (iOS compact only)
                #if os(iOS)
                if isCompact {
                    quickActionsSection(project)
                }
                #endif
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
        #if os(iOS)
        .refreshable {
            await viewModel.loadProject(id: projectId)
        }
        #endif
    }

    // MARK: - Archive Banner

    private var archiveBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Project Archived")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("No new feedback can be submitted")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Unarchive") {
                showingArchiveAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - API Key Card

    private func apiKeyCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("API Key", systemImage: "key.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    showingRegenerateAlert = true
                } label: {
                    Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.orange)
            }

            HStack(spacing: 12) {
                Text(project.apiKey)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                Button {
                    copyToClipboard(project.apiKey)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                        if !isCompact {
                            Text(copiedToClipboard ? "Copied" : "Copy")
                        }
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(copiedToClipboard ? .green : .accentColor)
                .animation(.easeInOut(duration: 0.2), value: copiedToClipboard)
            }

            Text("Use this key in your app with the SwiftlyFeedback SDK")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Stats Grid

    private func statsGrid(_ project: Project) -> some View {
        let columns = isCompact
            ? [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            StatCard(
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: .blue,
                title: "Feedback",
                value: "\(project.feedbackCount)"
            )

            StatCard(
                icon: "person.2.fill",
                iconColor: .green,
                title: "Members",
                value: "\(project.memberCount)"
            )

            if let createdAt = project.createdAt {
                StatCard(
                    icon: "calendar",
                    iconColor: .purple,
                    title: "Created",
                    value: createdAt.formatted(date: .abbreviated, time: .omitted)
                )
            }

            if let ownerEmail = project.ownerEmail {
                StatCard(
                    icon: "person.fill",
                    iconColor: .orange,
                    title: "Owner",
                    value: ownerEmail.components(separatedBy: "@").first ?? ownerEmail
                )
            }

            if project.isArchived, let archivedAt = project.archivedAt {
                StatCard(
                    icon: "archivebox.fill",
                    iconColor: .orange,
                    title: "Archived",
                    value: archivedAt.formatted(date: .abbreviated, time: .omitted)
                )
            }
        }
    }

    // MARK: - Description Card

    private func descriptionCard(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Description", systemImage: "text.alignleft")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Integrations Card

    private func integrationsCard(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Integrations", systemImage: "puzzlepiece.extension")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 0) {
                if project.isSlackConfigured {
                    integrationRow(
                        icon: "number",
                        iconColor: Color(red: 0.24, green: 0.58, blue: 0.55),
                        name: "Slack",
                        detail: project.slackIsActive ? "Notifications enabled" : "Paused",
                        isActive: project.slackIsActive
                    ) {
                        showingSlackSheet = true
                    }
                }

                if project.isGitHubConfigured {
                    if project.isSlackConfigured {
                        Divider()
                            .padding(.leading, 44)
                    }
                    integrationRow(
                        icon: "arrow.triangle.branch",
                        iconColor: .black,
                        name: "GitHub",
                        detail: project.githubIsActive ? "\(project.githubOwner ?? "")/\(project.githubRepo ?? "")" : "Paused",
                        isActive: project.githubIsActive
                    ) {
                        showingGitHubSheet = true
                    }
                }

                if project.isClickUpConfigured {
                    if project.isSlackConfigured || project.isGitHubConfigured {
                        Divider()
                            .padding(.leading, 44)
                    }
                    integrationRow(
                        icon: "checklist",
                        iconColor: Color(red: 0.49, green: 0.31, blue: 0.83),
                        name: "ClickUp",
                        detail: project.clickupIsActive ? (project.clickupListName ?? "Connected") : "Paused",
                        isActive: project.clickupIsActive
                    ) {
                        showingClickUpSheet = true
                    }
                }

                if project.isNotionConfigured {
                    if project.isSlackConfigured || project.isGitHubConfigured || project.isClickUpConfigured {
                        Divider()
                            .padding(.leading, 44)
                    }
                    integrationRow(
                        icon: "doc.text",
                        iconColor: .black,
                        name: "Notion",
                        detail: project.notionIsActive ? (project.notionDatabaseName ?? "Connected") : "Paused",
                        isActive: project.notionIsActive
                    ) {
                        showingNotionSheet = true
                    }
                }

                if project.isMondayConfigured {
                    if project.isSlackConfigured || project.isGitHubConfigured || project.isClickUpConfigured || project.isNotionConfigured {
                        Divider()
                            .padding(.leading, 44)
                    }
                    integrationRow(
                        icon: "calendar",
                        iconColor: Color(red: 1.0, green: 0.27, blue: 0.38),
                        name: "Monday.com",
                        detail: project.mondayIsActive ? (project.mondayBoardName ?? "Connected") : "Paused",
                        isActive: project.mondayIsActive
                    ) {
                        showingMondaySheet = true
                    }
                }

                if project.isLinearConfigured {
                    if project.isSlackConfigured || project.isGitHubConfigured || project.isClickUpConfigured || project.isNotionConfigured || project.isMondayConfigured {
                        Divider()
                            .padding(.leading, 44)
                    }
                    integrationRow(
                        icon: "arrow.triangle.branch",
                        iconColor: Color(red: 0.35, green: 0.39, blue: 0.95),
                        name: "Linear",
                        detail: project.linearIsActive ? (project.linearTeamName ?? "Connected") : "Paused",
                        isActive: project.linearIsActive
                    ) {
                        showingLinearSheet = true
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func integrationRow(
        icon: String,
        iconColor: Color,
        name: String,
        detail: String,
        isActive: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(isActive ? iconColor : Color.gray, in: RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(isActive ? Color.secondary : Color.orange)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions (iOS Compact)

    #if os(iOS)
    private func quickActionsSection(_ project: Project) -> some View {
        VStack(spacing: 0) {
            QuickActionButton(
                icon: "pencil",
                iconColor: .indigo,
                title: "Edit Project",
                subtitle: "Change name and description"
            ) {
                showingEditSheet = true
            }

            Divider()
                .padding(.leading, 56)

            QuickActionButton(
                icon: "person.2",
                iconColor: .green,
                title: "Manage Members",
                subtitle: "\(project.memberCount) team members"
            ) {
                if subscriptionService.meetsRequirement(.team) {
                    showingMembersSheet = true
                } else {
                    paywallRequiredTier = .team
                    showingPaywall = true
                }
            }
            .overlay(alignment: .trailing) {
                if !subscriptionService.meetsRequirement(.team) {
                    Text("Team")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue, in: Capsule())
                        .padding(.trailing, 40)
                }
            }

            Divider()
                .padding(.leading, 56)

            QuickActionButton(
                icon: project.isArchived ? "archivebox" : "archivebox.fill",
                iconColor: .orange,
                title: project.isArchived ? "Unarchive Project" : "Archive Project",
                subtitle: project.isArchived ? "Allow new feedback" : "Disable new feedback"
            ) {
                showingArchiveAlert = true
            }

            Divider()
                .padding(.leading, 56)

            QuickActionButton(
                icon: "trash",
                iconColor: .red,
                title: "Delete Project",
                subtitle: "Permanently remove project"
            ) {
                showingDeleteAlert = true
            }
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    #endif

    // MARK: - Helpers

    private func copyToClipboard(_ text: String) {
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif

        withAnimation {
            copiedToClipboard = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedToClipboard = false
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var showChevron: Bool = false

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

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Quick Action Button (iOS)

#if os(iOS)
struct QuickActionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(iconColor, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
#endif

// MARK: - Edit Project View

struct EditProjectView: View {
    let project: Project
    @Bindable var viewModel: ProjectViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var selectedColorIndex: Int
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case name, description
    }

    private static let gradientColors: [(Color, Color)] = [
        (.blue, .purple),
        (.green, .teal),
        (.orange, .red),
        (.pink, .purple),
        (.indigo, .blue),
        (.teal, .cyan),
        (.purple, .pink),
        (.mint, .green)
    ]

    init(project: Project, viewModel: ProjectViewModel) {
        self.project = project
        self.viewModel = viewModel
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description ?? "")
        _selectedColorIndex = State(initialValue: project.colorIndex)
    }

    private var hasChanges: Bool {
        name != project.name ||
        description != (project.description ?? "") ||
        selectedColorIndex != project.colorIndex
    }

    private var colorPickerGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 50, maximum: 60), spacing: 12)], spacing: 12) {
            ForEach(0..<Self.gradientColors.count, id: \.self) { index in
                let colors = Self.gradientColors[index]
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedColorIndex = index
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [colors.0, colors.1],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        if selectedColorIndex == index {
                            Circle()
                                .strokeBorder(.white, lineWidth: 3)
                                .frame(width: 44, height: 44)
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project Name", text: $name)
                        .focused($focusedField, equals: .name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                } header: {
                    Text("Name")
                } footer: {
                    Text("Choose a clear, descriptive name for your project.")
                }

                Section {
                    TextField("Description", text: $description, axis: .vertical)
                        .focused($focusedField, equals: .description)
                        .lineLimit(3...8)
                } header: {
                    Text("Description")
                } footer: {
                    Text("Optional. Describe the purpose of this project.")
                }

                Section {
                    colorPickerGrid
                } header: {
                    Text("Icon Color")
                } footer: {
                    Text("Choose a color for your project icon.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Edit Project")
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
                        Task {
                            if await viewModel.updateProject(
                                id: project.id,
                                name: name != project.name ? name : nil,
                                description: description != (project.description ?? "") ? description : nil,
                                colorIndex: selectedColorIndex != project.colorIndex ? selectedColorIndex : nil
                            ) {
                                dismiss()
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        !hasChanges ||
                        viewModel.isLoading
                    )
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
            .onAppear {
                focusedField = .name
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }
}

// MARK: - Previews

#Preview("Project Detail") {
    NavigationStack {
        ProjectDetailView(projectId: UUID(), viewModel: ProjectViewModel())
    }
}

#Preview("Edit Project") {
    EditProjectView(
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
