import SwiftUI

// MARK: - Sort Option

enum FeedbackSortOption: String, CaseIterable {
    case votes
    case mrr
    case newest
    case oldest

    var displayName: String {
        switch self {
        case .votes: return "Votes"
        case .mrr: return "MRR"
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        }
    }

    var icon: String {
        switch self {
        case .votes: return "arrow.up"
        case .mrr: return "dollarsign.circle"
        case .newest: return "clock"
        case .oldest: return "clock.arrow.circlepath"
        }
    }
}

@MainActor
@Observable
final class FeedbackViewModel {
    // MARK: - Properties

    var feedbacks: [Feedback] = []
    var selectedFeedback: Feedback?
    var comments: [Comment] = []

    var isLoading = false
    var isLoadingComments = false
    var errorMessage: String?
    var showError = false
    var successMessage: String?
    var showSuccess = false

    // Filter state
    var statusFilter: FeedbackStatus?
    var categoryFilter: FeedbackCategory?
    var searchText = ""
    var sortOption: FeedbackSortOption = .votes

    // New comment field
    var newCommentContent = ""

    // Multi-select for merging (Cmd/Ctrl+click)
    var selectedFeedbackIds: Set<UUID> = []
    var showMergeSheet = false
    var feedbacksToMerge: [Feedback] = []

    // Track current project
    private var currentProjectId: UUID?
    private var currentApiKey: String?
    private var isLoadingFeedbacks = false
    private var currentCommentsFeedbackId: UUID?

    // MARK: - Computed Properties

    var filteredFeedbacks: [Feedback] {
        var result = feedbacks

        if let status = statusFilter {
            result = result.filter { $0.status == status }
        }

        if let category = categoryFilter {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                ($0.userEmail?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply sorting
        switch sortOption {
        case .votes:
            result.sort { $0.voteCount > $1.voteCount }
        case .mrr:
            result.sort { ($0.totalMrr ?? 0) > ($1.totalMrr ?? 0) }
        case .newest:
            result.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest:
            result.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        }

        return result
    }

    var feedbacksByStatus: [FeedbackStatus: [Feedback]] {
        var result: [FeedbackStatus: [Feedback]] = [:]
        for status in FeedbackStatus.allCases {
            result[status] = filteredFeedbacks.filter { $0.status == status }
        }
        return result
    }

    /// Whether we can merge (need at least 2 selected feedbacks)
    var canMerge: Bool {
        selectedFeedbackIds.count >= 2
    }

    /// Get selected feedbacks in order
    var selectedFeedbacks: [Feedback] {
        feedbacks.filter { selectedFeedbackIds.contains($0.id) }
    }

    // MARK: - Multi-Select for Merge

    func toggleSelection(_ id: UUID) {
        if selectedFeedbackIds.contains(id) {
            selectedFeedbackIds.remove(id)
        } else {
            selectedFeedbackIds.insert(id)
        }
    }

    func isSelected(_ id: UUID) -> Bool {
        selectedFeedbackIds.contains(id)
    }

    func clearSelection() {
        selectedFeedbackIds.removeAll()
    }

    /// Start merge flow with the given feedback as one of the items to merge
    func startMerge(with feedback: Feedback) {
        // Include the right-clicked feedback plus any already selected
        var feedbackIds = selectedFeedbackIds
        feedbackIds.insert(feedback.id)

        feedbacksToMerge = feedbacks.filter { feedbackIds.contains($0.id) }

        if feedbacksToMerge.count >= 2 {
            showMergeSheet = true
        }
    }

    /// Start merge with currently selected feedbacks
    func startMergeWithSelection() {
        feedbacksToMerge = selectedFeedbacks
        if feedbacksToMerge.count >= 2 {
            showMergeSheet = true
        }
    }

    // MARK: - Load Feedbacks

    func loadFeedbacks(projectId: UUID, apiKey: String) async {
        guard !isLoadingFeedbacks else {
            AppLogger.viewModel.debug("⏭️ loadFeedbacks skipped - already loading")
            return
        }

        isLoadingFeedbacks = true
        isLoading = true
        errorMessage = nil
        currentProjectId = projectId
        currentApiKey = apiKey

        do {
            feedbacks = try await AdminAPIClient.shared.getFeedbacks(apiKey: apiKey)
            AppLogger.viewModel.info("✅ Feedbacks loaded: \(self.feedbacks.count)")
        } catch {
            AppLogger.viewModel.error("❌ Failed to load feedbacks: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
        isLoadingFeedbacks = false
    }

    func refreshFeedbacks() async {
        guard let projectId = currentProjectId, let apiKey = currentApiKey else { return }
        await loadFeedbacks(projectId: projectId, apiKey: apiKey)
    }

    // MARK: - Load Single Feedback

    func loadFeedback(id: UUID, apiKey: String) async {
        isLoading = true
        errorMessage = nil

        do {
            selectedFeedback = try await AdminAPIClient.shared.getFeedback(id: id, apiKey: apiKey)
            AppLogger.viewModel.info("✅ Feedback loaded: \(id)")
        } catch {
            AppLogger.viewModel.error("❌ Failed to load feedback: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Update Feedback Status

    func updateFeedbackStatus(id: UUID, status: FeedbackStatus) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = UpdateFeedbackRequest(title: nil, description: nil, status: status, category: nil)
            let updated: Feedback = try await AdminAPIClient.shared.patch(path: "feedbacks/\(id)", body: request)

            // Update local state
            if let index = feedbacks.firstIndex(where: { $0.id == id }) {
                feedbacks[index] = updated
            }
            if selectedFeedback?.id == id {
                selectedFeedback = updated
            }

            AppLogger.viewModel.info("✅ Feedback status updated to \(status.rawValue)")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to update feedback status: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Update Feedback Category

    func updateFeedbackCategory(id: UUID, category: FeedbackCategory) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let request = UpdateFeedbackRequest(title: nil, description: nil, status: nil, category: category)
            let updated: Feedback = try await AdminAPIClient.shared.patch(path: "feedbacks/\(id)", body: request)

            // Update local state
            if let index = feedbacks.firstIndex(where: { $0.id == id }) {
                feedbacks[index] = updated
            }
            if selectedFeedback?.id == id {
                selectedFeedback = updated
            }

            AppLogger.viewModel.info("✅ Feedback category updated to \(category.rawValue)")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to update feedback category: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Delete Feedback

    func deleteFeedback(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AdminAPIClient.shared.delete(path: "feedbacks/\(id)")
            feedbacks.removeAll { $0.id == id }
            if selectedFeedback?.id == id {
                selectedFeedback = nil
            }
            AppLogger.viewModel.info("✅ Feedback deleted: \(id)")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to delete feedback: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Comments

    func loadComments(feedbackId: UUID, apiKey: String) async {
        // Skip if already loading comments for this feedback
        guard !isLoadingComments || currentCommentsFeedbackId != feedbackId else {
            AppLogger.viewModel.debug("⏭️ loadComments skipped - already loading for \(feedbackId)")
            return
        }

        // Skip if we already have comments for this feedback (unless it's a different feedback)
        if currentCommentsFeedbackId == feedbackId && !comments.isEmpty {
            AppLogger.viewModel.debug("⏭️ loadComments skipped - already loaded for \(feedbackId)")
            return
        }

        isLoadingComments = true
        currentCommentsFeedbackId = feedbackId

        do {
            comments = try await AdminAPIClient.shared.getComments(feedbackId: feedbackId, apiKey: apiKey)
            AppLogger.viewModel.info("✅ Comments loaded: \(self.comments.count)")
        } catch {
            AppLogger.viewModel.error("❌ Failed to load comments: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
        }

        isLoadingComments = false
    }

    func addComment(feedbackId: UUID, apiKey: String, userId: String) async -> Bool {
        let content = newCommentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            showError(message: "Comment cannot be empty")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let comment = try await AdminAPIClient.shared.createComment(
                feedbackId: feedbackId,
                content: content,
                userId: userId,
                isAdmin: true,
                apiKey: apiKey
            )
            comments.append(comment)
            newCommentContent = ""
            AppLogger.viewModel.info("✅ Comment added")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to add comment: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func deleteComment(feedbackId: UUID, commentId: UUID, apiKey: String) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            try await AdminAPIClient.shared.deleteComment(feedbackId: feedbackId, commentId: commentId, apiKey: apiKey)
            comments.removeAll { $0.id == commentId }
            AppLogger.viewModel.info("✅ Comment deleted: \(commentId)")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to delete comment: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
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

    func clearFilters() {
        statusFilter = nil
        categoryFilter = nil
        searchText = ""
        sortOption = .votes
    }

    // MARK: - Merge Feedback

    func mergeFeedback(primaryId: UUID) async -> Bool {
        let secondaryIds = feedbacksToMerge.map { $0.id }.filter { $0 != primaryId }

        guard !secondaryIds.isEmpty else {
            showError(message: "No secondary feedbacks to merge")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.mergeFeedback(
                primaryId: primaryId,
                secondaryIds: secondaryIds
            )

            // Update primary feedback in local array
            if let index = feedbacks.firstIndex(where: { $0.id == primaryId }) {
                feedbacks[index] = response.primaryFeedback
            }

            // Remove secondary feedbacks from local array
            feedbacks.removeAll { secondaryIds.contains($0.id) }

            // Clear selection
            clearSelection()
            feedbacksToMerge = []

            AppLogger.viewModel.info("✅ Feedback merged: \(response.mergedCount) items merged, \(response.totalVotes) total votes")
            showSuccess(message: "Successfully merged \(response.mergedCount) feedback items")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to merge feedback: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - GitHub Integration

    func createGitHubIssue(projectId: UUID, feedbackId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.createGitHubIssue(
                projectId: projectId,
                feedbackId: feedbackId
            )

            // Reload feedbacks to get the updated GitHub fields
            // since our response only contains the URL and number
            if feedbacks.contains(where: { $0.id == feedbackId }) {
                await refreshFeedbacks()
            }

            AppLogger.viewModel.info("✅ GitHub issue created: \(response.issueUrl)")
            showSuccess(message: "GitHub issue #\(response.issueNumber) created")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create GitHub issue: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func bulkCreateGitHubIssues(projectId: UUID) async -> Bool {
        // Get feedbacks that don't already have GitHub issues
        let feedbackIds = selectedFeedbacks
            .filter { !$0.hasGitHubIssue }
            .map { $0.id }

        guard !feedbackIds.isEmpty else {
            showError(message: "No feedbacks to push to GitHub (all selected items already have issues)")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.bulkCreateGitHubIssues(
                projectId: projectId,
                feedbackIds: feedbackIds
            )

            // Refresh to get updated GitHub fields
            await refreshFeedbacks()

            // Clear selection
            clearSelection()

            if response.failed.isEmpty {
                AppLogger.viewModel.info("✅ GitHub issues created: \(response.created.count)")
                showSuccess(message: "Created \(response.created.count) GitHub issues")
            } else {
                AppLogger.viewModel.warning("⚠️ GitHub issues created with some failures: \(response.created.count) created, \(response.failed.count) failed")
                showSuccess(message: "Created \(response.created.count) GitHub issues (\(response.failed.count) failed)")
            }

            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create GitHub issues: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - ClickUp Integration

    func createClickUpTask(projectId: UUID, feedbackId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.createClickUpTask(
                projectId: projectId,
                feedbackId: feedbackId
            )

            // Refresh to get updated ClickUp fields
            await refreshFeedbacks()

            AppLogger.viewModel.info("✅ ClickUp task created: \(response.taskUrl)")
            showSuccess(message: "ClickUp task created")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create ClickUp task: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func bulkCreateClickUpTasks(projectId: UUID) async -> Bool {
        // Get feedbacks that don't already have ClickUp tasks
        let feedbackIds = selectedFeedbacks
            .filter { !$0.hasClickUpTask }
            .map { $0.id }

        guard !feedbackIds.isEmpty else {
            showError(message: "No feedbacks to push to ClickUp (all selected items already have tasks)")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.bulkCreateClickUpTasks(
                projectId: projectId,
                feedbackIds: feedbackIds
            )

            // Refresh to get updated ClickUp fields
            await refreshFeedbacks()

            // Clear selection
            clearSelection()

            if response.failed.isEmpty {
                AppLogger.viewModel.info("✅ ClickUp tasks created: \(response.created.count)")
                showSuccess(message: "Created \(response.created.count) ClickUp tasks")
            } else {
                AppLogger.viewModel.warning("⚠️ ClickUp tasks created with some failures: \(response.created.count) created, \(response.failed.count) failed")
                showSuccess(message: "Created \(response.created.count) ClickUp tasks (\(response.failed.count) failed)")
            }

            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create ClickUp tasks: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Notion Integration

    func createNotionPage(projectId: UUID, feedbackId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.createNotionPage(
                projectId: projectId,
                feedbackId: feedbackId
            )

            // Refresh to get updated Notion fields
            await refreshFeedbacks()

            AppLogger.viewModel.info("✅ Notion page created: \(response.pageUrl)")
            showSuccess(message: "Notion page created")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create Notion page: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func bulkCreateNotionPages(projectId: UUID) async -> Bool {
        // Get feedbacks that don't already have Notion pages
        let feedbackIds = selectedFeedbacks
            .filter { !$0.hasNotionPage }
            .map { $0.id }

        guard !feedbackIds.isEmpty else {
            showError(message: "No feedbacks to push to Notion (all selected items already have pages)")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.bulkCreateNotionPages(
                projectId: projectId,
                feedbackIds: feedbackIds
            )

            // Refresh to get updated Notion fields
            await refreshFeedbacks()

            // Clear selection
            clearSelection()

            if response.failed.isEmpty {
                AppLogger.viewModel.info("✅ Notion pages created: \(response.created.count)")
                showSuccess(message: "Created \(response.created.count) Notion pages")
            } else {
                AppLogger.viewModel.warning("⚠️ Notion pages created with some failures: \(response.created.count) created, \(response.failed.count) failed")
                showSuccess(message: "Created \(response.created.count) Notion pages (\(response.failed.count) failed)")
            }

            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create Notion pages: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Monday.com Integration

    func createMondayItem(projectId: UUID, feedbackId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.createMondayItem(
                projectId: projectId,
                feedbackId: feedbackId
            )

            // Refresh to get updated Monday fields
            await refreshFeedbacks()

            AppLogger.viewModel.info("✅ Monday.com item created: \(response.itemUrl)")
            showSuccess(message: "Monday.com item created")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create Monday.com item: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func bulkCreateMondayItems(projectId: UUID) async -> Bool {
        // Get feedbacks that don't already have Monday items
        let feedbackIds = selectedFeedbacks
            .filter { !$0.hasMondayItem }
            .map { $0.id }

        guard !feedbackIds.isEmpty else {
            showError(message: "No feedbacks to push to Monday.com (all selected items already have items)")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.bulkCreateMondayItems(
                projectId: projectId,
                feedbackIds: feedbackIds
            )

            // Refresh to get updated Monday fields
            await refreshFeedbacks()

            // Clear selection
            clearSelection()

            if response.failed.isEmpty {
                AppLogger.viewModel.info("✅ Monday.com items created: \(response.created.count)")
                showSuccess(message: "Created \(response.created.count) Monday.com items")
            } else {
                AppLogger.viewModel.warning("⚠️ Monday.com items created with some failures: \(response.created.count) created, \(response.failed.count) failed")
                showSuccess(message: "Created \(response.created.count) Monday.com items (\(response.failed.count) failed)")
            }

            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create Monday.com items: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Linear Integration

    func createLinearIssue(projectId: UUID, feedbackId: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.createLinearIssue(
                projectId: projectId,
                feedbackId: feedbackId
            )

            // Refresh to get updated Linear fields
            await refreshFeedbacks()

            AppLogger.viewModel.info("✅ Linear issue created: \(response.issueUrl)")
            showSuccess(message: "Linear issue \(response.identifier) created")
            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create Linear issue: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    func bulkCreateLinearIssues(projectId: UUID) async -> Bool {
        // Get feedbacks that don't already have Linear issues
        let feedbackIds = selectedFeedbacks
            .filter { !$0.hasLinearIssue }
            .map { $0.id }

        guard !feedbackIds.isEmpty else {
            showError(message: "No feedbacks to push to Linear (all selected items already have issues)")
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await AdminAPIClient.shared.bulkCreateLinearIssues(
                projectId: projectId,
                feedbackIds: feedbackIds
            )

            // Refresh to get updated Linear fields
            await refreshFeedbacks()

            // Clear selection
            clearSelection()

            if response.failed.isEmpty {
                AppLogger.viewModel.info("✅ Linear issues created: \(response.created.count)")
                showSuccess(message: "Created \(response.created.count) Linear issues")
            } else {
                AppLogger.viewModel.warning("⚠️ Linear issues created with some failures: \(response.created.count) created, \(response.failed.count) failed")
                showSuccess(message: "Created \(response.created.count) Linear issues (\(response.failed.count) failed)")
            }

            isLoading = false
            return true
        } catch {
            AppLogger.viewModel.error("❌ Failed to create Linear issues: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }
}
