import Foundation
import SwiftUI
import OSLog

@MainActor
@Observable
final class HomeDashboardViewModel {
    var dashboard: HomeDashboard?
    var isLoading = false
    var showError = false
    var errorMessage: String?
    var selectedProjectId: UUID?

    var filteredProjectStats: [ProjectStats] {
        guard let dashboard = dashboard else { return [] }

        if let selectedId = selectedProjectId {
            return dashboard.projectStats.filter { $0.id == selectedId }
        }
        return dashboard.projectStats
    }

    var displayStats: DisplayStats {
        guard let dashboard = dashboard else {
            return DisplayStats.empty
        }

        if let selectedId = selectedProjectId,
           let projectStats = dashboard.projectStats.first(where: { $0.id == selectedId }) {
            return DisplayStats(
                totalProjects: nil,
                totalFeedback: projectStats.feedbackCount,
                feedbackByStatus: projectStats.feedbackByStatus,
                totalUsers: projectStats.userCount,
                totalComments: projectStats.commentCount,
                totalVotes: projectStats.voteCount
            )
        }

        return DisplayStats(
            totalProjects: dashboard.totalProjects,
            totalFeedback: dashboard.totalFeedback,
            feedbackByStatus: dashboard.feedbackByStatus,
            totalUsers: dashboard.totalUsers,
            totalComments: dashboard.totalComments,
            totalVotes: dashboard.totalVotes
        )
    }

    struct DisplayStats {
        let totalProjects: Int?
        let totalFeedback: Int
        let feedbackByStatus: FeedbackByStatus
        let totalUsers: Int
        let totalComments: Int
        let totalVotes: Int

        static let empty = DisplayStats(
            totalProjects: 0,
            totalFeedback: 0,
            feedbackByStatus: FeedbackByStatus(pending: 0, approved: 0, inProgress: 0, completed: 0, rejected: 0),
            totalUsers: 0,
            totalComments: 0,
            totalVotes: 0
        )
    }

    func loadDashboard() async {
        Logger.viewModel.info("HomeDashboardViewModel: loadDashboard called")

        guard !isLoading else {
            Logger.viewModel.warning("HomeDashboardViewModel: loadDashboard skipped - already loading")
            return
        }

        // Skip if we already have data
        guard dashboard == nil else {
            Logger.viewModel.debug("HomeDashboardViewModel: loadDashboard skipped - already have data")
            return
        }

        isLoading = true
        Logger.viewModel.debug("HomeDashboardViewModel: Starting to load dashboard...")

        do {
            let loadedDashboard = try await AdminAPIClient.shared.getHomeDashboard()
            Logger.viewModel.info("HomeDashboardViewModel: Successfully loaded dashboard with \(loadedDashboard.totalProjects) projects, \(loadedDashboard.totalFeedback) feedback items")

            dashboard = loadedDashboard

        } catch let error as APIError {
            Logger.viewModel.error("HomeDashboardViewModel: APIError - \(error.localizedDescription)")
            // Don't show error for cancelled requests (view lifecycle)
            if case .networkError(let underlyingError) = error,
               (underlyingError as NSError).code == NSURLErrorCancelled {
                Logger.viewModel.debug("HomeDashboardViewModel: Request cancelled, will retry on next appear")
            } else {
                errorMessage = error.localizedDescription
                showError = true
            }
        } catch {
            Logger.viewModel.error("HomeDashboardViewModel: Unknown error - \(error.localizedDescription)")
            // Don't show error for cancelled requests
            if (error as NSError).code == NSURLErrorCancelled {
                Logger.viewModel.debug("HomeDashboardViewModel: Request cancelled, will retry on next appear")
            } else {
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        isLoading = false
        Logger.viewModel.debug("HomeDashboardViewModel: loadDashboard completed, isLoading = false")
    }

    func refreshDashboard() async {
        Logger.viewModel.info("HomeDashboardViewModel: refreshDashboard called")
        dashboard = nil  // Clear data to allow reload
        await loadDashboard()
    }

    func selectProject(_ projectId: UUID?) {
        Logger.viewModel.info("HomeDashboardViewModel: selectProject - \(projectId?.uuidString ?? "All Projects")")
        selectedProjectId = projectId
    }
}
