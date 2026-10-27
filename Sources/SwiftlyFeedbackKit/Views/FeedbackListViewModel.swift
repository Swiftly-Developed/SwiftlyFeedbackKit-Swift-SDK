import SwiftUI

@MainActor
@Observable
final class FeedbackListViewModel {
    /// Four-state load model; `feedbackItems` and the body arms derive from it.
    private(set) var state: FeedbackLoadState = .idle
    /// Action flag for refreshes over a populated list — state stays `.loaded`
    /// and rows stay on screen while this is `true`.
    var isRefreshing = false
    /// No-flash grace flag: set 150 ms into an initial load, only if still loading.
    private(set) var showSkeleton = false
    var searchText = ""
    var searchTokens: [FeedbackSearchToken] = []
    var showingSubmitSheet = false
    var showingError = false
    var errorMessage: String?
    var showingSubmissionDisabledAlert = false
    var showingModerationNotice = false
    var moderationNotice: String?
    var hasInvalidApiKey = false
    /// Items the user toggled back to their original-language text. Session-scoped
    /// per-item choice: lives exactly as long as this view model, never persisted.
    var showOriginalIDs: Set<UUID> = []
    /// Session-only status and category filters, applied client-side. Never persisted.
    var filter = FeedbackListFilter()
    var selectedSort: FeedbackSortOption = .votes {
        didSet {
            UserDefaults.standard.set(selectedSort.rawValue, forKey: Self.sortOptionDefaultsKey)
            sortFeedback()
        }
    }

    // Vote dialog state
    var showingVoteDialog = false
    var voteEmail = ""
    var voteNotifyStatusChange = false
    var voteSubscribeToMailingList = SwiftlyFeedback.configuration.mailingListDefaultOptIn
    var voteOperationalEmails = true
    var voteMarketingEmails = true
    var pendingVoteFeedbackId: UUID?

    let swiftlyFeedback: SwiftlyFeedback?

    private static let sortOptionDefaultsKey = "com.swiftlyfeedback.sdk.sortOption"

    private var loadTask: Task<Void, Never>?
    private var graceTask: Task<Void, Never>?
    /// Monotonic token: only the most recent load may write shared state on the
    /// way out (a superseded load's cancellation must not clobber its successor).
    private var loadGeneration = 0

    init(swiftlyFeedback: SwiftlyFeedback?) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.current
        self.voteNotifyStatusChange = SwiftlyFeedback.configuration.voteNotificationDefaultOptIn
        // Observers don't fire during init, so this restore neither re-writes
        // the default nor triggers a sort on the still-idle state.
        let storedSort = UserDefaults.standard.string(forKey: Self.sortOptionDefaultsKey) ?? ""
        self.selectedSort = FeedbackSortOption(rawValue: storedSort) ?? .votes
    }

    /// The loaded collection, or `[]` before a load has completed.
    var feedbackItems: [Feedback] {
        if case .loaded(let items) = state { return items }
        return []
    }

    /// The loaded collection after client-side search and filtering, in sort order.
    var displayedItems: [Feedback] {
        Self.displayedItems(from: feedbackItems, searchText: searchText, tokens: searchTokens, filter: filter)
    }

    var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !searchTokens.isEmpty
    }

    /// The body to show once loaded. Project-empty wins, then filtered-empty, then search-empty.
    var branch: FeedbackListBranch {
        Self.branch(
            loaded: feedbackItems,
            displayed: displayedItems,
            isSearchActive: isSearchActive,
            isFilterActive: filter.isActive
        )
    }

    func clearSearch() {
        searchText = ""
        searchTokens = []
    }

    /// Removes the status and category filters. Sort and search text are kept.
    func clearFilters() {
        filter.clear()
    }

    /// Text matches title or description. Status and category tokens still narrow the list
    /// when a caller has set them; the menu filters combine with all of it by AND.
    nonisolated static func displayedItems(
        from items: [Feedback],
        searchText: String,
        tokens: [FeedbackSearchToken],
        filter: FeedbackListFilter
    ) -> [Feedback] {
        var items = items
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.title.localizedStandardContains(query) || $0.description.localizedStandardContains(query)
            }
        }
        let statuses = tokens.compactMap { if case .status(let s) = $0 { s } else { nil } }
        if !statuses.isEmpty {
            items = items.filter { statuses.contains($0.status) }
        }
        let categories = tokens.compactMap { if case .category(let c) = $0 { c } else { nil } }
        if !categories.isEmpty {
            items = items.filter { categories.contains($0.category) }
        }
        if filter.isActive {
            items = items.filter(filter.matches)
        }
        return items
    }

    nonisolated static func branch(
        loaded: [Feedback],
        displayed: [Feedback],
        isSearchActive: Bool,
        isFilterActive: Bool
    ) -> FeedbackListBranch {
        if loaded.isEmpty { return .projectEmpty }
        guard displayed.isEmpty else { return .populated }
        if isFilterActive { return .filteredEmpty }
        return isSearchActive ? .searchEmpty : .populated
    }

    /// Flips one item between its translation and its original text.
    func toggleShowOriginal(_ id: UUID) {
        if showOriginalIDs.contains(id) {
            showOriginalIDs.remove(id)
        } else {
            showOriginalIDs.insert(id)
        }
    }

    func retryAfterInvalidApiKey() {
        // Must reset BEFORE loading — loadFeedback's guard refuses otherwise.
        hasInvalidApiKey = false
        Task { await loadFeedback() }
    }

    func loadFeedback(isUserPull: Bool = false) async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        // Cancel any in-flight request
        loadTask?.cancel()
        graceTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration

        let isInitialLoad: Bool
        if case .loaded = state {
            isInitialLoad = false
        } else {
            isInitialLoad = true
        }

        if isInitialLoad {
            state = .loading
            showSkeleton = false
            // 150 ms no-flash grace: loads faster than this never paint a skeleton.
            graceTask = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled, generation == loadGeneration else { return }
                if case .loading = state { showSkeleton = true }
            }
        } else if !isUserPull {
            // Programmatic refresh over a populated list: rows stay on screen,
            // the top inset shows the indicator. User pulls keep the system spinner.
            isRefreshing = true
        }

        let task = Task {
            do {
                try Task.checkCancellation()
                let items = try await sf.getFeedback()
                try Task.checkCancellation()
                state = .loaded(Self.sorted(items, by: selectedSort))
            } catch is CancellationError {
                // Third outcome: a cancelled load with nothing loaded resets to
                // .idle so the next `.task` retries — never a stranded skeleton.
                // A superseded load (generation moved on) leaves state to its successor.
                if generation == loadGeneration, isInitialLoad {
                    state = .idle
                }
            } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
                hasInvalidApiKey = true
            } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
                // Never "Something went wrong" for the limit: the upgrade message
                // rides .failed on initial load, the alert on populated refresh.
                handleLoadFailure(message ?? String(localized: .errorFeedbackLimitMessage))
            } catch {
                handleLoadFailure(error.localizedDescription)
            }
            if generation == loadGeneration {
                graceTask?.cancel()
                showSkeleton = false
                isRefreshing = false
            }
        }

        loadTask = task
        await task.value
    }

    func loadFeedbackIfNeeded() async {
        guard state == .idle else { return }
        await loadFeedback()
    }

    /// Initial-load failures become the inline `.failed` arm; a refresh failure
    /// with rows on screen keeps `.loaded` and the existing alert path — rows
    /// are never blanked by a failed refresh.
    private func handleLoadFailure(_ message: String) {
        if case .loaded = state {
            errorMessage = message
            showingError = true
        } else {
            state = .failed(message: message)
        }
    }

    /// Writes the server's answer onto the voted row, as the detail screen does. No reload:
    /// a list read that lags the vote would put the old count back.
    private func applyVote(_ result: VoteResult) {
        guard case .loaded(let items) = state else { return }
        let updated = items.map { $0.id == result.feedbackId ? $0.applying(result) : $0 }
        state = .loaded(Self.sorted(updated, by: selectedSort))
    }

    private func sortFeedback() {
        guard case .loaded(let items) = state else { return }
        // No withAnimation here: the view's `.animation(value:)` observes the
        // change and routes it through MotionPolicy.
        state = .loaded(Self.sorted(items, by: selectedSort))
    }

    nonisolated static func sorted(_ items: [Feedback], by sort: FeedbackSortOption) -> [Feedback] {
        switch sort {
        case .votes:
            return items.sorted { $0.voteCount > $1.voteCount }
        case .newest:
            return items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest:
            return items.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .comments:
            return items.sorted { $0.commentCount > $1.commentCount }
        }
    }

    func toggleVote(for feedback: Feedback) async {
        guard swiftlyFeedback != nil else { return }
        guard !hasInvalidApiKey else { return }

        let config = SwiftlyFeedback.configuration

        if feedback.hasVoted {
            // Unvoting - no dialog needed
            if !config.allowUndoVote { return }
            await submitVote(for: feedback.id, email: nil, notify: false)
        } else {
            // Check if userEmail is already configured
            let configuredEmail = config.userEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasConfiguredEmail = configuredEmail?.isEmpty == false

            if hasConfiguredEmail {
                // Use configured email directly, no dialog needed
                await submitVote(for: feedback.id, email: configuredEmail, notify: config.voteNotificationDefaultOptIn, subscribeToMailingList: config.mailingListDefaultOptIn, mailingListEmailTypes: buildVoteEmailTypes())
            } else if config.showVoteEmailField {
                // No configured email - show dialog to collect email
                voteEmail = ""
                voteNotifyStatusChange = config.voteNotificationDefaultOptIn
                voteSubscribeToMailingList = config.mailingListDefaultOptIn
                pendingVoteFeedbackId = feedback.id
                showingVoteDialog = true
            } else {
                // No email configured and dialog disabled - vote without email
                await submitVote(for: feedback.id, email: nil, notify: false)
            }
        }
    }

    func buildVoteEmailTypes() -> [String]? {
        guard voteSubscribeToMailingList else { return nil }
        var types: [String] = []
        if voteOperationalEmails { types.append("operational") }
        if voteMarketingEmails { types.append("marketing") }
        return types.isEmpty ? nil : types
    }

    func submitVote(for feedbackId: UUID, email: String?, notify: Bool, subscribeToMailingList: Bool? = nil, mailingListEmailTypes: [String]? = nil) async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        do {
            let result: VoteResult
            // Check if this is an unvote by finding the feedback
            if let feedback = feedbackItems.first(where: { $0.id == feedbackId }), feedback.hasVoted {
                result = try await sf.unvote(for: feedbackId)
            } else {
                let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
                let validEmail = (trimmedEmail?.isEmpty == false) ? trimmedEmail : nil
                result = try await sf.vote(
                    for: feedbackId,
                    email: validEmail,
                    notifyStatusChange: notify && validEmail != nil,
                    subscribeToMailingList: validEmail != nil ? subscribeToMailingList : nil,
                    mailingListEmailTypes: validEmail != nil && subscribeToMailingList == true ? mailingListEmailTypes : nil
                )
            }
            applyVote(result)
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: .errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    /// Stores a report and shows the acknowledgement on this board.
    func report(_ feedback: Feedback, reason: ContentReportReason) async {
        guard let sf = swiftlyFeedback else {
            present(SwiftlyFeedbackError.invalidResponse)
            return
        }
        do {
            _ = try await sf.reportFeedback(id: feedback.id, reason: reason)
            moderationNotice = String(localized: .moderationReportThanks)
            showingModerationNotice = true
        } catch {
            present(error)
        }
    }

    /// Hides this author's posts and comments, then reloads the board.
    func blockAuthor(of feedback: Feedback) async {
        guard let sf = swiftlyFeedback else {
            present(SwiftlyFeedbackError.invalidResponse)
            return
        }
        do {
            _ = try await sf.blockUser(id: feedback.userId)
            noteAuthorBlocked()
            await loadFeedback()
        } catch {
            present(error)
        }
    }

    private func present(_ error: any Error) {
        errorMessage = error.localizedDescription
        showingError = true
    }

    /// The detail screen dismissed after its post's author was blocked.
    func noteAuthorBlocked() {
        moderationNotice = String(localized: .moderationBlockThanks)
        showingModerationNotice = true
    }
}
