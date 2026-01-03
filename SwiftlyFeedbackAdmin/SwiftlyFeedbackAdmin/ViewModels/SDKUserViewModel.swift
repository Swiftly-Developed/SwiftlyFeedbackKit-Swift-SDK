import Foundation
import SwiftUI
import OSLog

@MainActor
@Observable
final class SDKUserViewModel {
    var users: [SDKUser] = []
    var stats: SDKUserStats?
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var searchText = ""
    var sortOrder: SortOrder = .lastSeen

    enum SortOrder: String, CaseIterable {
        case lastSeen = "Last Seen"
        case mrr = "MRR"
        case feedbackCount = "Feedback"
        case voteCount = "Votes"

        var icon: String {
            switch self {
            case .lastSeen: return "clock"
            case .mrr: return "dollarsign.circle"
            case .feedbackCount: return "bubble.left"
            case .voteCount: return "arrow.up"
            }
        }
    }

    private var currentProjectId: UUID?

    var filteredUsers: [SDKUser] {
        var result = users

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter { user in
                user.userId.localizedCaseInsensitiveContains(searchText)
            }
            Logger.viewModel.debug("SDKUserViewModel: Filtered to \(result.count) users with search '\(self.searchText)'")
        }

        // Apply sort
        switch sortOrder {
        case .lastSeen:
            result.sort { ($0.lastSeenAt ?? .distantPast) > ($1.lastSeenAt ?? .distantPast) }
        case .mrr:
            result.sort { ($0.mrr ?? 0) > ($1.mrr ?? 0) }
        case .feedbackCount:
            result.sort { $0.feedbackCount > $1.feedbackCount }
        case .voteCount:
            result.sort { $0.voteCount > $1.voteCount }
        }

        return result
    }

    func loadUsers(projectId: UUID) async {
        Logger.viewModel.info("SDKUserViewModel: loadUsers called for projectId: \(projectId.uuidString)")

        guard !isLoading else {
            Logger.viewModel.warning("SDKUserViewModel: loadUsers skipped - already loading")
            return
        }

        currentProjectId = projectId
        isLoading = true
        Logger.viewModel.debug("SDKUserViewModel: Starting to load users and stats...")

        do {
            Logger.viewModel.info("SDKUserViewModel: Fetching users and stats in parallel...")
            async let usersResult = AdminAPIClient.shared.getSDKUsers(projectId: projectId)
            async let statsResult = AdminAPIClient.shared.getSDKUserStats(projectId: projectId)

            let (loadedUsers, loadedStats) = try await (usersResult, statsResult)

            Logger.viewModel.info("SDKUserViewModel: Successfully loaded \(loadedUsers.count) users")
            Logger.viewModel.info("SDKUserViewModel: Stats - totalUsers: \(loadedStats.totalUsers), totalMrr: \(loadedStats.totalMrr), usersWithMrr: \(loadedStats.usersWithMrr)")

            users = loadedUsers
            stats = loadedStats

            // Log first few users for debugging
            for (index, user) in loadedUsers.prefix(3).enumerated() {
                Logger.viewModel.debug("SDKUserViewModel: User[\(index)] - id: \(user.id.uuidString), userId: \(user.userId), mrr: \(user.mrr ?? 0)")
            }

        } catch let error as APIError {
            Logger.viewModel.error("SDKUserViewModel: APIError - \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            Logger.viewModel.error("SDKUserViewModel: Unknown error - \(error.localizedDescription)")
            Logger.viewModel.error("SDKUserViewModel: Error type: \(type(of: error))")
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
        Logger.viewModel.debug("SDKUserViewModel: loadUsers completed, isLoading = false")
    }

    func refreshUsers() async {
        Logger.viewModel.info("SDKUserViewModel: refreshUsers called")
        guard let projectId = currentProjectId else {
            Logger.viewModel.warning("SDKUserViewModel: refreshUsers skipped - no currentProjectId")
            return
        }
        await loadUsers(projectId: projectId)
    }
}
