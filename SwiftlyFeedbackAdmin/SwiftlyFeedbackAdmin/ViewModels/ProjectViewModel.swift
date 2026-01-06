import SwiftUI

@MainActor
@Observable
final class ProjectViewModel {
    var projects: [ProjectListItem] = []
    var selectedProject: Project?
    var projectMembers: [ProjectMember] = []

    /// Shared project filter selection across Feedback, Users, and Events tabs.
    /// nil means "All Projects" for tabs that support it.
    var selectedFilterProject: ProjectListItem?

    var isLoading = false
    var isLoadingDetail = false
    var errorMessage: String?
    var showError = false
    var successMessage: String?
    var showSuccess = false
    var pendingInvites: [ProjectInvite] = []

    // Create project fields
    var newProjectName = ""
    var newProjectDescription = ""

    // Add member fields
    var newMemberEmail = ""
    var newMemberRole: ProjectRole = .member

    // Track if projects are currently being loaded to prevent duplicate requests
    private var isLoadingProjects = false

    func loadProjects() async {
        // Prevent duplicate concurrent requests
        guard !isLoadingProjects else {
            AppLogger.viewModel.debug("⏭️ loadProjects skipped - already loading")
            return
        }

        isLoadingProjects = true
        isLoading = true
        errorMessage = nil

        do {
            projects = try await AdminAPIClient.shared.get(path: "projects")
            AppLogger.viewModel.info("✅ Projects loaded: \(self.projects.count)")
        } catch {
            AppLogger.viewModel.error("❌ Failed to load projects: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
        isLoadingProjects = false
    }

    func loadProject(id: UUID) async {
        AppLogger.viewModel.info("📂 Loading project details for: \(id.uuidString)")
        isLoadingDetail = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.get(path: "projects/\(id)")
            AppLogger.viewModel.info("✅ Project loaded: \(self.selectedProject?.name ?? "nil")")
        } catch {
            AppLogger.viewModel.error("❌ Failed to load project \(id.uuidString): \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoadingDetail = false
    }

    func createProject() async -> Bool {
        guard !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError(message: "Project name is required")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let request = CreateProjectRequest(
                name: newProjectName.trimmingCharacters(in: .whitespacesAndNewlines),
                description: newProjectDescription.isEmpty ? nil : newProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            let _: Project = try await AdminAPIClient.shared.post(path: "projects", body: request)
            clearCreateProjectFields()
            await loadProjects()
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func updateProject(id: UUID, name: String?, description: String?, colorIndex: Int? = nil) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = UpdateProjectRequest(name: name, description: description, colorIndex: colorIndex)
            selectedProject = try await AdminAPIClient.shared.patch(path: "projects/\(id)", body: request)
            await loadProjects()
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func deleteProject(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AdminAPIClient.shared.delete(path: "projects/\(id)")
            await loadProjects()
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func archiveProject(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.post(path: "projects/\(id)/archive", body: EmptyBody())
            await loadProjects()
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func unarchiveProject(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.post(path: "projects/\(id)/unarchive", body: EmptyBody())
            await loadProjects()
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func regenerateApiKey(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.post(path: "projects/\(id)/regenerate-key", body: EmptyBody())
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Members

    func loadMembers(projectId: UUID) async {
        do {
            projectMembers = try await AdminAPIClient.shared.get(path: "projects/\(projectId)/members")
        } catch {
            showError(message: error.localizedDescription)
        }
    }

    func addMember(projectId: UUID) async -> Bool {
        guard !newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError(message: "Email is required")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let request = AddMemberRequest(
                email: newMemberEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                role: newMemberRole
            )
            let response: AddMemberResponse = try await AdminAPIClient.shared.post(path: "projects/\(projectId)/members", body: request)
            clearAddMemberFields()

            if response.inviteSent {
                showSuccess(message: "Invitation email sent successfully")
                await loadInvites(projectId: projectId)
            } else {
                await loadMembers(projectId: projectId)
            }

            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func updateMemberRole(projectId: UUID, memberId: UUID, role: ProjectRole) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = UpdateMemberRoleRequest(role: role)
            let _: ProjectMember = try await AdminAPIClient.shared.patch(
                path: "projects/\(projectId)/members/\(memberId)",
                body: request
            )
            await loadMembers(projectId: projectId)
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func removeMember(projectId: UUID, memberId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AdminAPIClient.shared.delete(path: "projects/\(projectId)/members/\(memberId)")
            await loadMembers(projectId: projectId)
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Invites

    func loadInvites(projectId: UUID) async {
        do {
            pendingInvites = try await AdminAPIClient.shared.get(path: "projects/\(projectId)/invites")
        } catch {
            // Silent failure - invites are supplementary
        }
    }

    func cancelInvite(projectId: UUID, inviteId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AdminAPIClient.shared.delete(path: "projects/\(projectId)/invites/\(inviteId)")
            await loadInvites(projectId: projectId)
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func resendInvite(projectId: UUID, inviteId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let _: ProjectInvite = try await AdminAPIClient.shared.post(path: "projects/\(projectId)/invites/\(inviteId)/resend", body: EmptyBody())
            showSuccess(message: "Invitation email resent successfully")
            await loadInvites(projectId: projectId)
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Slack Settings

    func updateSlackSettings(
        projectId: UUID,
        slackWebhookUrl: String?,
        slackNotifyNewFeedback: Bool?,
        slackNotifyNewComments: Bool?,
        slackNotifyStatusChanges: Bool?,
        slackIsActive: Bool?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.updateProjectSlackSettings(
                projectId: projectId,
                slackWebhookUrl: slackWebhookUrl,
                slackNotifyNewFeedback: slackNotifyNewFeedback,
                slackNotifyNewComments: slackNotifyNewComments,
                slackNotifyStatusChanges: slackNotifyStatusChanges,
                slackIsActive: slackIsActive
            )
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Status Settings

    func updateAllowedStatuses(projectId: UUID, allowedStatuses: [String]) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.updateProjectAllowedStatuses(
                projectId: projectId,
                allowedStatuses: allowedStatuses
            )
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - GitHub Settings

    func updateGitHubSettings(
        projectId: UUID,
        githubOwner: String?,
        githubRepo: String?,
        githubToken: String?,
        githubDefaultLabels: [String]?,
        githubSyncStatus: Bool?,
        githubIsActive: Bool?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.updateProjectGitHubSettings(
                projectId: projectId,
                githubOwner: githubOwner,
                githubRepo: githubRepo,
                githubToken: githubToken,
                githubDefaultLabels: githubDefaultLabels,
                githubSyncStatus: githubSyncStatus,
                githubIsActive: githubIsActive
            )
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - ClickUp Settings

    func updateClickUpSettings(
        projectId: UUID,
        clickupToken: String?,
        clickupListId: String?,
        clickupWorkspaceName: String?,
        clickupListName: String?,
        clickupDefaultTags: [String]?,
        clickupSyncStatus: Bool?,
        clickupSyncComments: Bool?,
        clickupVotesFieldId: String?,
        clickupIsActive: Bool?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.updateProjectClickUpSettings(
                projectId: projectId,
                clickupToken: clickupToken,
                clickupListId: clickupListId,
                clickupWorkspaceName: clickupWorkspaceName,
                clickupListName: clickupListName,
                clickupDefaultTags: clickupDefaultTags,
                clickupSyncStatus: clickupSyncStatus,
                clickupSyncComments: clickupSyncComments,
                clickupVotesFieldId: clickupVotesFieldId,
                clickupIsActive: clickupIsActive
            )
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func loadClickUpWorkspaces(projectId: UUID) async -> [ClickUpWorkspace] {
        do {
            return try await AdminAPIClient.shared.getClickUpWorkspaces(projectId: projectId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadClickUpSpaces(projectId: UUID, workspaceId: String) async -> [ClickUpSpace] {
        do {
            return try await AdminAPIClient.shared.getClickUpSpaces(projectId: projectId, workspaceId: workspaceId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadClickUpFolders(projectId: UUID, spaceId: String) async -> [ClickUpFolder] {
        do {
            return try await AdminAPIClient.shared.getClickUpFolders(projectId: projectId, spaceId: spaceId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadClickUpLists(projectId: UUID, folderId: String) async -> [ClickUpList] {
        do {
            return try await AdminAPIClient.shared.getClickUpLists(projectId: projectId, folderId: folderId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadClickUpFolderlessLists(projectId: UUID, spaceId: String) async -> [ClickUpList] {
        do {
            return try await AdminAPIClient.shared.getClickUpFolderlessLists(projectId: projectId, spaceId: spaceId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadClickUpCustomFields(projectId: UUID) async -> [ClickUpCustomField] {
        do {
            return try await AdminAPIClient.shared.getClickUpCustomFields(projectId: projectId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    // MARK: - Notion Settings

    func updateNotionSettings(
        projectId: UUID,
        notionToken: String?,
        notionDatabaseId: String?,
        notionDatabaseName: String?,
        notionSyncStatus: Bool?,
        notionSyncComments: Bool?,
        notionStatusProperty: String?,
        notionVotesProperty: String?,
        notionIsActive: Bool?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.updateProjectNotionSettings(
                projectId: projectId,
                notionToken: notionToken,
                notionDatabaseId: notionDatabaseId,
                notionDatabaseName: notionDatabaseName,
                notionSyncStatus: notionSyncStatus,
                notionSyncComments: notionSyncComments,
                notionStatusProperty: notionStatusProperty,
                notionVotesProperty: notionVotesProperty,
                notionIsActive: notionIsActive
            )
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func loadNotionDatabases(projectId: UUID) async -> [NotionDatabase] {
        do {
            return try await AdminAPIClient.shared.getNotionDatabases(projectId: projectId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadNotionDatabaseProperties(projectId: UUID, databaseId: String) async -> NotionDatabase? {
        do {
            return try await AdminAPIClient.shared.getNotionDatabaseProperties(projectId: projectId, databaseId: databaseId)
        } catch {
            showError(message: error.localizedDescription)
            return nil
        }
    }

    // MARK: - Monday.com Settings

    func updateMondaySettings(
        projectId: UUID,
        mondayToken: String?,
        mondayBoardId: String?,
        mondayBoardName: String?,
        mondayGroupId: String?,
        mondayGroupName: String?,
        mondaySyncStatus: Bool?,
        mondaySyncComments: Bool?,
        mondayStatusColumnId: String?,
        mondayVotesColumnId: String?,
        mondayIsActive: Bool?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.updateProjectMondaySettings(
                projectId: projectId,
                mondayToken: mondayToken,
                mondayBoardId: mondayBoardId,
                mondayBoardName: mondayBoardName,
                mondayGroupId: mondayGroupId,
                mondayGroupName: mondayGroupName,
                mondaySyncStatus: mondaySyncStatus,
                mondaySyncComments: mondaySyncComments,
                mondayStatusColumnId: mondayStatusColumnId,
                mondayVotesColumnId: mondayVotesColumnId,
                mondayIsActive: mondayIsActive
            )
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func loadMondayBoards(projectId: UUID) async -> [MondayBoard] {
        do {
            return try await AdminAPIClient.shared.getMondayBoards(projectId: projectId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadMondayGroups(projectId: UUID, boardId: String) async -> [MondayGroup] {
        do {
            return try await AdminAPIClient.shared.getMondayGroups(projectId: projectId, boardId: boardId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadMondayColumns(projectId: UUID, boardId: String) async -> [MondayColumn] {
        do {
            return try await AdminAPIClient.shared.getMondayColumns(projectId: projectId, boardId: boardId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    // MARK: - Linear Integration

    func updateLinearSettings(
        projectId: UUID,
        linearToken: String?,
        linearTeamId: String?,
        linearTeamName: String?,
        linearProjectId: String?,
        linearProjectName: String?,
        linearDefaultLabelIds: [String]?,
        linearSyncStatus: Bool?,
        linearSyncComments: Bool?,
        linearIsActive: Bool?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = UpdateProjectLinearRequest(
                linearToken: linearToken,
                linearTeamId: linearTeamId,
                linearTeamName: linearTeamName,
                linearProjectId: linearProjectId,
                linearProjectName: linearProjectName,
                linearDefaultLabelIds: linearDefaultLabelIds,
                linearSyncStatus: linearSyncStatus,
                linearSyncComments: linearSyncComments,
                linearIsActive: linearIsActive
            )
            let updated = try await AdminAPIClient.shared.updateLinearSettings(projectId: projectId, request: request)
            selectedProject = updated
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func loadLinearTeams(projectId: UUID) async -> [LinearTeam] {
        do {
            return try await AdminAPIClient.shared.getLinearTeams(projectId: projectId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadLinearProjects(projectId: UUID, teamId: String) async -> [LinearProject] {
        do {
            return try await AdminAPIClient.shared.getLinearProjects(projectId: projectId, teamId: teamId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    func loadLinearLabels(projectId: UUID, teamId: String) async -> [LinearLabel] {
        do {
            return try await AdminAPIClient.shared.getLinearLabels(projectId: projectId, teamId: teamId)
        } catch {
            showError(message: error.localizedDescription)
            return []
        }
    }

    // MARK: - Accept Invite

    var inviteCode = ""
    var invitePreview: InvitePreview?

    func previewInviteCode() async -> Bool {
        let code = inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            showError(message: "Please enter an invite code")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            invitePreview = try await AdminAPIClient.shared.get(path: "invites/preview/\(code)")
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func acceptInviteCode() async -> Bool {
        let code = inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            showError(message: "Please enter an invite code")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let request = AcceptInviteRequest(code: code)
            let response: AcceptInviteResponse = try await AdminAPIClient.shared.post(path: "invites/accept", body: request)
            showSuccess(message: "You've joined \(response.projectName) as \(response.role.displayName)")
            clearInviteFields()
            await loadProjects()
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func clearInviteFields() {
        inviteCode = ""
        invitePreview = nil
    }

    // MARK: - Helpers

    private func showError(message: String) {
        errorMessage = message
        showError = true
    }

    private func showSuccess(message: String) {
        successMessage = message
        showSuccess = true
    }

    private func clearCreateProjectFields() {
        newProjectName = ""
        newProjectDescription = ""
    }

    private func clearAddMemberFields() {
        newMemberEmail = ""
        newMemberRole = .member
    }
}

private struct EmptyBody: Encodable {}
