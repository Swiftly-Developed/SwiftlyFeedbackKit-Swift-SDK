import SwiftUI

/// A ready-to-use view that displays a list of feedback items
public struct FeedbackListView: View {
    @State private var viewModel: FeedbackListViewModel
    @State private var translator = FeedbackTranslator()
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.locale) private var locale

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    public init(swiftlyFeedback: SwiftlyFeedback? = nil) {
        _viewModel = State(wrappedValue: FeedbackListViewModel(swiftlyFeedback: swiftlyFeedback))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasInvalidApiKey {
                    InvalidApiKeyView(onRetry: viewModel.retryAfterInvalidApiKey)
                } else {
                    switch viewModel.state {
                    case .idle, .loading:
                        // One arm for "not requested yet" and "in flight":
                        // the honest render for both is the loading skeleton.
                        // The 150 ms grace flag keeps fast loads from flashing it.
                        if viewModel.showSkeleton {
                            FeedbackListSkeletonView()
                        } else {
                            Color.clear
                        }
                    case .failed(let message):
                        InlineErrorView(message: message) {
                            Task { await viewModel.loadFeedback() }
                        }
                    case .loaded(let items):
                        if items.isEmpty {
                            FeedbackEmptyStateView(
                                onSubmit: { viewModel.showingSubmitSheet = true },
                                onSubmitDisabled: { viewModel.showingSubmissionDisabledAlert = true }
                            )
                        } else if viewModel.isSearchActive && viewModel.displayedItems.isEmpty {
                            FeedbackSearchEmptyStateView {
                                viewModel.clearSearch()
                            }
                        } else {
                            FeedbackListContentView(viewModel: viewModel, translator: translator)
                                .safeAreaInset(edge: .top) {
                                    if viewModel.isRefreshing {
                                        FeedbackListRefreshIndicatorView()
                                    }
                                }
                        }
                    }
                }
            }
            .searchable(
                text: $viewModel.searchText,
                tokens: $viewModel.searchTokens,
                suggestedTokens: .constant(viewModel.suggestedTokens),
                prompt: Text(Strings.searchPrompt)
            ) { token in
                Label(token.displayName, systemImage: token.iconName)
            }
            .navigationTitle(Strings.feedbackListTitle)
            .toolbar {
                if !viewModel.hasInvalidApiKey {
                    #if os(macOS)
                    ToolbarItem(placement: .navigation) {
                        Button {
                            Task { await viewModel.loadFeedback() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.state == .loading || viewModel.isRefreshing)
                        .keyboardShortcut("r", modifiers: .command)
                        .help(Strings.toolbarRefresh)
                    }
                    #endif

                    ToolbarItem(placement: .automatic) {
                        Menu {
                            // Sort options
                            Picker(selection: $viewModel.selectedSort) {
                                ForEach(FeedbackSortOption.allCases, id: \.self) { option in
                                    Text(option.localizedName).tag(option)
                                }
                            } label: {
                                Label(Strings.toolbarSort, systemImage: "arrow.up.arrow.down")
                            }

                            // Status filter (if enabled)
                            if config.buttons.statusFilter.display {
                                Divider()

                                Picker(selection: $viewModel.selectedStatus) {
                                    Text(Strings.filterAll).tag(FeedbackStatus?.none)
                                    ForEach(FeedbackStatus.allCases, id: \.self) { status in
                                        Text(status.localizedDisplayName).tag(FeedbackStatus?.some(status))
                                    }
                                } label: {
                                    Label(Strings.toolbarStatus, systemImage: "line.3.horizontal.decrease.circle")
                                }
                            }
                        } label: {
                            // Authored name: the menu contains both sort and filter,
                            // so it is named for both — never a "More…"-family default.
                            Label(Strings.toolbarSortAndFilter, systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }

                    if config.buttons.addButton.display {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                if config.allowFeedbackSubmission {
                                    viewModel.showingSubmitSheet = true
                                } else {
                                    viewModel.showingSubmissionDisabledAlert = true
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel(Strings.submitFeedbackTitle)
                            .tint(theme.primaryColor.resolve(for: colorScheme))
                        }
                    }
                }
            }
            .alert(Strings.feedbackSubmissionDisabledTitle, isPresented: $viewModel.showingSubmissionDisabledAlert) {
                Button(Strings.errorOK, role: .cancel) {}
            } message: {
                Text(config.feedbackSubmissionDisabledMessage ?? Strings.feedbackSubmissionDisabledMessage)
            }
            .sheet(isPresented: $viewModel.showingSubmitSheet) {
                SubmitFeedbackView(swiftlyFeedback: viewModel.swiftlyFeedback) {
                    viewModel.showingSubmitSheet = false
                    Task { await viewModel.loadFeedback() }
                }
            }
            .refreshable {
                // The system pull spinner is the refresh indicator here — the
                // inset capsule is for programmatic refreshes only (no doubling).
                await viewModel.loadFeedback(isUserPull: true)
            }
            .task {
                await viewModel.loadFeedbackIfNeeded()
            }
            .feedbackTranslationTask(translator)
            .onChange(of: viewModel.feedbackItems, initial: true) {
                enqueueTranslations()
            }
            .onChange(of: locale) {
                // A locale change invalidates every cached projection (the target
                // moved), then re-detects and re-enqueues against the new target.
                translator.invalidateAll()
                enqueueTranslations()
            }
            .onAppear {
                if SwiftlyFeedback.config.enableAutomaticViewTracking {
                    SwiftlyFeedback.view(.feedbackList)
                }
            }
            .alert(Strings.errorTitle, isPresented: $viewModel.showingError) {
                Button(Strings.errorOK, role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? Strings.errorGeneric)
            }
            .sheet(isPresented: $viewModel.showingVoteDialog) {
                VoteDialogView(
                    email: $viewModel.voteEmail,
                    notifyStatusChange: $viewModel.voteNotifyStatusChange,
                    subscribeToMailingList: $viewModel.voteSubscribeToMailingList,
                    operationalEmails: $viewModel.voteOperationalEmails,
                    marketingEmails: $viewModel.voteMarketingEmails
                ) { email, notify, subscribeToMailingList, mailingListEmailTypes in
                    // List-specific routing: the dialog commits against the
                    // feedback that opened it, guarded so a stale commit no-ops.
                    guard let feedbackId = viewModel.pendingVoteFeedbackId else { return }
                    viewModel.pendingVoteFeedbackId = nil
                    Task {
                        await viewModel.submitVote(
                            for: feedbackId,
                            email: email,
                            notify: notify,
                            subscribeToMailingList: subscribeToMailingList,
                            mailingListEmailTypes: mailingListEmailTypes
                        )
                    }
                }
            }
        }
    }

    /// Detects source languages per field across the loaded items and queues the
    /// uncached remainder toward the current locale. Skipped entirely when the
    /// target locale carries no language code (nothing to translate toward).
    private func enqueueTranslations() {
        let target = locale.language
        guard target.languageCode != nil else { return }
        let units = viewModel.feedbackItems.flatMap {
            SourceLanguageDetector.units(for: $0, target: target)
        }
        translator.enqueue(units: units, target: target)
    }
}

struct FeedbackEmptyStateView: View {
    let onSubmit: () -> Void
    let onSubmitDisabled: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    var body: some View {
        ContentUnavailableView {
            Label(Strings.feedbackListEmpty, systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text(Strings.feedbackListEmptyDescription)
        } actions: {
            Button(Strings.submitFeedbackTitle) {
                if config.allowFeedbackSubmission {
                    onSubmit()
                } else {
                    onSubmitDisabled()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primaryColor.resolve(for: colorScheme))
        }
    }
}

struct FeedbackListContentView: View {
    @Bindable var viewModel: FeedbackListViewModel
    let translator: FeedbackTranslator
    private var motion = MotionPolicy()

    @SwiftUI.Environment(\.locale) private var locale

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    init(viewModel: FeedbackListViewModel, translator: FeedbackTranslator) {
        self.viewModel = viewModel
        self.translator = translator
    }

    /// The card's translation inputs for one item: cached projections plus the
    /// localized source-language name. All `nil` (affordance absent, original text
    /// stands) until the cache fills — and stays all `nil` when the source language
    /// has no localized display name, because a raw code is never shown.
    private func translationProjection(
        for feedback: Feedback
    ) -> (title: String?, description: String?, sourceName: String?) {
        let target = locale.language
        let title = translator.translation(
            for: feedback.id, field: .title, target: target, sourceText: feedback.title
        )
        let description = translator.translation(
            for: feedback.id, field: .description, target: target, sourceText: feedback.description
        )
        guard title != nil || description != nil else { return (nil, nil, nil) }
        let source = SourceLanguageDetector.detect(feedback.description)
            ?? SourceLanguageDetector.detect(feedback.title)
        guard let sourceName = source?.localizedDisplayName(in: locale) else {
            return (nil, nil, nil)
        }
        return (title, description, sourceName)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.displayedItems) { feedback in
                    let projection = translationProjection(for: feedback)
                    let isShowingOriginal = viewModel.showOriginalIDs.contains(feedback.id)
                    let cardView = FeedbackCardView(
                        feedback: feedback,
                        onVote: { Task { await viewModel.toggleVote(for: feedback) } },
                        translatedTitle: projection.title,
                        translatedDescription: projection.description,
                        translationSourceName: projection.sourceName,
                        isShowingOriginal: isShowingOriginal,
                        onToggleTranslation: { viewModel.toggleShowOriginal(feedback.id) }
                    )
                    let link = NavigationLink(value: feedback) {
                        cardView
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(cardView.accessibilityDescription)
                    .accessibilityHint(Strings.accessibilityViewDetails)

                    // `children: .ignore` hides the affordance's inner Button from
                    // VoiceOver, so the toggle is re-exposed as a named rotor action
                    // — only when the affordance is actually mounted.
                    Group {
                        if projection.sourceName != nil {
                            link.accessibilityAction(
                                named: isShowingOriginal ? Strings.showTranslation : Strings.showOriginal
                            ) {
                                viewModel.toggleShowOriginal(feedback.id)
                            }
                        } else {
                            link
                        }
                    }
                    .transition(motion.transition(.opacity.combined(with: .move(edge: .top))))
                }
            }
            .padding()
            .animation(motion.animation(.smooth), value: viewModel.displayedItems)
        }
        .navigationDestination(for: Feedback.self) { feedback in
            FeedbackDetailView(feedback: feedback, swiftlyFeedback: viewModel.swiftlyFeedback)
        }
    }
}

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
    var hasInvalidApiKey = false
    /// Items the user toggled back to their original-language text. Session-scoped
    /// per-item choice: lives exactly as long as this view model, never persisted.
    var showOriginalIDs: Set<UUID> = []
    var selectedStatus: FeedbackStatus? {
        didSet { Task { await loadFeedback() } }
    }
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
    var voteSubscribeToMailingList = SwiftlyFeedback.config.mailingListDefaultOptIn
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
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        self.voteNotifyStatusChange = SwiftlyFeedback.config.voteNotificationDefaultOptIn
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

    /// The loaded collection after client-side search filtering: text matches
    /// title OR description; tokens AND across families, OR within a family.
    var displayedItems: [Feedback] {
        var items = feedbackItems
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter {
                $0.title.localizedStandardContains(query) || $0.description.localizedStandardContains(query)
            }
        }
        let statuses = searchTokens.compactMap { if case .status(let s) = $0 { s } else { nil } }
        if !statuses.isEmpty {
            items = items.filter { statuses.contains($0.status) }
        }
        let categories = searchTokens.compactMap { if case .category(let c) = $0 { c } else { nil } }
        if !categories.isEmpty {
            items = items.filter { categories.contains($0.category) }
        }
        return items
    }

    var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !searchTokens.isEmpty
    }

    /// Status tokens are the distinct statuses present in the loaded collection
    /// (never an always-empty filter; the SDK has no allowed-statuses endpoint);
    /// category tokens are all four cases.
    var suggestedTokens: [FeedbackSearchToken] {
        let presentStatuses = FeedbackStatus.allCases.filter { status in
            feedbackItems.contains { $0.status == status }
        }
        return presentStatuses.map { .status($0) } + FeedbackCategory.allCases.map { .category($0) }
    }

    func clearSearch() {
        searchText = ""
        searchTokens = []
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
                let items = try await sf.getFeedback(status: selectedStatus)
                try Task.checkCancellation()
                state = .loaded(sorted(items))
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
                handleLoadFailure(message ?? Strings.errorFeedbackLimitMessage)
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

    private func sortFeedback() {
        guard case .loaded(let items) = state else { return }
        // No withAnimation here: the view's `.animation(value:)` observes the
        // change and routes it through MotionPolicy.
        state = .loaded(sorted(items))
    }

    private func sorted(_ items: [Feedback]) -> [Feedback] {
        switch selectedSort {
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

        let config = SwiftlyFeedback.config

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
            // Check if this is an unvote by finding the feedback
            if let feedback = feedbackItems.first(where: { $0.id == feedbackId }), feedback.hasVoted {
                _ = try await sf.unvote(for: feedbackId)
            } else {
                let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
                let validEmail = (trimmedEmail?.isEmpty == false) ? trimmedEmail : nil
                _ = try await sf.vote(
                    for: feedbackId,
                    email: validEmail,
                    notifyStatusChange: notify && validEmail != nil,
                    subscribeToMailingList: validEmail != nil ? subscribeToMailingList : nil,
                    mailingListEmailTypes: validEmail != nil && subscribeToMailingList == true ? mailingListEmailTypes : nil
                )
            }
            await loadFeedback()
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? Strings.errorFeedbackLimitMessage
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
