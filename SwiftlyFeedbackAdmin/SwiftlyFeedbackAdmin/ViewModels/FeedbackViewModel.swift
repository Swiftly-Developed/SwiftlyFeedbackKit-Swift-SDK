import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.swiftlyfeedback.admin", category: "FeedbackViewModel")

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

    // Track current project
    private var currentProjectId: UUID?
    private var currentApiKey: String?
    private var isLoadingFeedbacks = false

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

    // MARK: - Load Feedbacks

    func loadFeedbacks(projectId: UUID, apiKey: String) async {
        guard !isLoadingFeedbacks else {
            logger.debug("⏭️ loadFeedbacks skipped - already loading")
            return
        }

        isLoadingFeedbacks = true
        isLoading = true
        errorMessage = nil
        currentProjectId = projectId
        currentApiKey = apiKey

        do {
            feedbacks = try await AdminAPIClient.shared.getFeedbacks(apiKey: apiKey)
            logger.info("✅ Feedbacks loaded: \(self.feedbacks.count)")
        } catch {
            logger.error("❌ Failed to load feedbacks: \(error.localizedDescription)")
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
            logger.info("✅ Feedback loaded: \(id)")
        } catch {
            logger.error("❌ Failed to load feedback: \(error.localizedDescription)")
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

            logger.info("✅ Feedback status updated to \(status.rawValue)")
            isLoading = false
            return true
        } catch {
            logger.error("❌ Failed to update feedback status: \(error.localizedDescription)")
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

            logger.info("✅ Feedback category updated to \(category.rawValue)")
            isLoading = false
            return true
        } catch {
            logger.error("❌ Failed to update feedback category: \(error.localizedDescription)")
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
            logger.info("✅ Feedback deleted: \(id)")
            isLoading = false
            return true
        } catch {
            logger.error("❌ Failed to delete feedback: \(error.localizedDescription)")
            showError(message: error.localizedDescription)
            isLoading = false
            return false
        }
    }

    // MARK: - Comments

    func loadComments(feedbackId: UUID, apiKey: String) async {
        isLoadingComments = true

        do {
            comments = try await AdminAPIClient.shared.getComments(feedbackId: feedbackId, apiKey: apiKey)
            logger.info("✅ Comments loaded: \(self.comments.count)")
        } catch {
            logger.error("❌ Failed to load comments: \(error.localizedDescription)")
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
            logger.info("✅ Comment added")
            isLoading = false
            return true
        } catch {
            logger.error("❌ Failed to add comment: \(error.localizedDescription)")
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
            logger.info("✅ Comment deleted: \(commentId)")
            isLoading = false
            return true
        } catch {
            logger.error("❌ Failed to delete comment: \(error.localizedDescription)")
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
}
