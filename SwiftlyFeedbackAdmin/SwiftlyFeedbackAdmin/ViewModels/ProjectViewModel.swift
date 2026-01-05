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
        slackNotifyStatusChanges: Bool?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            selectedProject = try await AdminAPIClient.shared.updateProjectSlackSettings(
                projectId: projectId,
                slackWebhookUrl: slackWebhookUrl,
                slackNotifyNewFeedback: slackNotifyNewFeedback,
                slackNotifyNewComments: slackNotifyNewComments,
                slackNotifyStatusChanges: slackNotifyStatusChanges
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
        githubSyncStatus: Bool?
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
                githubSyncStatus: githubSyncStatus
            )
            isLoading = false
            return true
        } catch {
            showError(message: error.localizedDescription)
            isLoading = false
            return false
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
