import SwiftUI

/// A ready-to-use view that displays a list of feedback items
public struct FeedbackListView: View {
    @State private var viewModel: FeedbackListViewModel
    @State private var translator = FeedbackTranslator()
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.locale) private var locale
    #if !os(macOS)
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    // Owned by the VIEW, not by the preference store: that store is synchronous,
    // non-observable and holds no translator (TRANSLATION01 §18), so the selection state
    // has to live where the control does.
    @State private var supportedTargets: [Locale.Language] = []
    @State private var chosenTarget: Locale.Language?     // nil == follow the device
    private let targetStore = TranslationTargetStore()

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    /// What every derivation site on this surface reads.
    private var resolvedTarget: Locale.Language {
        chosenTarget ?? locale.language
    }

    /// Reading order for the picker's rows. A helper, not an inline filter
    /// (UI-DESIGN-IOS.md → "Helpers, not inline filters"), and the only place the
    /// ordering is computed — the control itself computes none (TRANSLATION01 §18).
    ///
    /// The ordered list is deliberately not stored back into `supportedTargets`: the
    /// stored-choice lookup is handed the *supported* set, and ordering drops languages
    /// with no localized name, so seeding from a pruned set would change what the
    /// preference is validated against.
    private var orderedTargets: [Locale.Language] {
        TranslationTargetOrdering.ordered(supported: supportedTargets, displayLocale: locale)
    }

    /// When false, the list adds no navigation container of its own at any width: the host
    /// already wrapped it in the one stack the rows push onto.
    private let embedsNavigationStack: Bool

    /// What the list wraps itself in on iOS and visionOS.
    enum Container: Equatable {
        case stack
        case split
        case none
    }

    /// A hosted list gets no container. A split of its own inside the host's stack hid the
    /// list behind a second Show Sidebar button on iPad.
    static func container(embedsNavigationStack: Bool, isCompact: Bool) -> Container {
        guard embedsNavigationStack else { return .none }
        return isCompact ? .stack : .split
    }

    public init(swiftlyFeedback: SwiftlyFeedback? = nil, embedsNavigationStack: Bool = true) {
        self.embedsNavigationStack = embedsNavigationStack
        _viewModel = State(wrappedValue: FeedbackListViewModel(swiftlyFeedback: swiftlyFeedback))
    }

    public var body: some View {
        #if os(macOS)
        NavigationStack {
            listColumn
        }
        #else
        // Compact is one stack. Regular width keeps the list beside an empty detail. A host
        // that owns navigation gets the bare list.
        switch Self.container(embedsNavigationStack: embedsNavigationStack, isCompact: horizontalSizeClass == .compact) {
        case .stack:
            NavigationStack {
                listColumn
            }
        case .split:
            NavigationSplitView {
                listColumn
            } detail: {
                ContentUnavailableView(
                    String(localized: .feedbackListTitle),
                    systemImage: "bubble.left.and.bubble.right"
                )
            }
        case .none:
            listColumn
        }
        #endif
    }

    private var listColumn: some View {
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
                            switch config.listStyle {
                            case .showcase: FeedbackShowcaseSkeletonView()
                            case .classic: FeedbackListSkeletonView()
                            }
                        } else {
                            Color.clear
                        }
                    case .failed(let message):
                        InlineErrorView(message: message) {
                            Task { await viewModel.loadFeedback() }
                        }
                    case .loaded:
                        switch viewModel.branch {
                        case .projectEmpty:
                            FeedbackEmptyStateView(
                                onSubmit: { viewModel.showingSubmitSheet = true },
                                onSubmitDisabled: { viewModel.showingSubmissionDisabledAlert = true }
                            )
                        case .filteredEmpty:
                            FeedbackFilterEmptyStateView {
                                viewModel.clearFilters()
                            }
                        case .searchEmpty:
                            FeedbackSearchEmptyStateView(query: viewModel.searchText) {
                                viewModel.clearSearch()
                            }
                        case .populated:
                            Group {
                                switch config.listStyle {
                                case .showcase:
                                    FeedbackShowcaseList(
                                        viewModel: viewModel,
                                        translator: translator,
                                        target: resolvedTarget
                                    )
                                case .classic:
                                    FeedbackListContentView(
                                        viewModel: viewModel,
                                        translator: translator,
                                        target: resolvedTarget
                                    )
                                }
                            }
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
                placement: .toolbar,
                prompt: Text(String(localized: .searchPrompt))
            )
            .navigationTitle(String(localized: .feedbackListTitle))
            .tint(theme.primaryColor.resolve(for: colorScheme))
            .toolbar {
                if !viewModel.hasInvalidApiKey {
                    let sortFilterMenu = FeedbackListSortFilterMenu(
                        selectedSort: $viewModel.selectedSort,
                        filter: $viewModel.filter,
                        showsStatusFilter: config.buttons.statusFilter.display,
                        showsCategoryFilter: config.buttons.categoryFilter.display,
                        orderedTargets: orderedTargets,
                        chosenTarget: $chosenTarget,
                        displayLocale: locale,
                        tint: theme.primaryColor.resolve(for: colorScheme)
                    )
                    let addButton = FeedbackListAddButton(
                        allowsSubmission: config.allowFeedbackSubmission,
                        tint: theme.primaryColor.resolve(for: colorScheme),
                        onSubmit: { viewModel.showingSubmitSheet = true },
                        onDisabled: { viewModel.showingSubmissionDisabledAlert = true }
                    )

                    #if os(macOS)
                    ToolbarItem(placement: .navigation) {
                        Button(String(localized: .toolbarRefresh), systemImage: "arrow.clockwise") {
                            Task { await viewModel.loadFeedback() }
                        }
                        .disabled(viewModel.state == .loading || viewModel.isRefreshing)
                        .keyboardShortcut("r", modifiers: .command)
                        .help(String(localized: .toolbarRefresh))
                    }
                    ToolbarItem(placement: .primaryAction) {
                        sortFilterMenu
                    }
                    if config.buttons.addButton.display {
                        ToolbarItem(placement: .primaryAction) {
                            addButton
                        }
                    }
                    #else
                    ToolbarItemGroup(placement: .primaryAction) {
                        sortFilterMenu
                        if config.buttons.addButton.display {
                            addButton
                        }
                    }
                    #endif
                }
            }
            .alert(String(localized: .feedbackSubmissionDisabledTitle), isPresented: $viewModel.showingSubmissionDisabledAlert) {
                Button(String(localized: .errorOk), role: .cancel) {}
            } message: {
                Text(config.feedbackSubmissionDisabledMessage ?? String(localized: .feedbackSubmissionDisabledMessage))
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
            .task {
                // A second task, deliberately not merged into the feedback fetch above:
                // the supported set is awaited from the translation framework and its
                // latency is unbounded, so merging would serialise that fetch behind it.
                //
                // The set is awaited exactly once per view entry, here. Seeding the
                // choice from it is what validates a stored value against what the
                // device actually offers.
                supportedTargets = await translator.supportedTargets()
                chosenTarget = targetStore.storedTarget(in: supportedTargets)
            }
            .onChange(of: chosenTarget) {
                targetStore.setTarget(chosenTarget)
            }
            .onChange(of: resolvedTarget) {
                // The target moved, so every cached projection is stale: drop them all,
                // then re-detect and re-enqueue against the new one. This is the device-
                // locale arm it replaces, widened — the resolved target already depends
                // on the environment locale, so today's behaviour is preserved, while a
                // device-language change made while the reader sits on an explicit target
                // now correctly invalidates nothing.
                translator.invalidateAll()
                enqueueTranslations()
            }
            .onAppear {
                if SwiftlyFeedback.configuration.enableAutomaticViewTracking {
                    SwiftlyFeedback.view(.feedbackList)
                }
            }
            .safeAreaInset(edge: .bottom) {
                BoardContactFooter(address: config.moderationContactEmail)
            }
            .alert(String(localized: .errorTitle), isPresented: $viewModel.showingError) {
                Button(String(localized: .errorOk), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? String(localized: .errorGeneric))
            }
            .alert(
                viewModel.moderationNotice ?? "",
                isPresented: $viewModel.showingModerationNotice
            ) {
                Button(String(localized: .errorOk), role: .cancel) {}
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

    /// Detects source languages per field across the loaded items and queues the
    /// uncached remainder toward the reader's resolved target. Skipped entirely when
    /// that target carries no language code (nothing to translate toward).
    private func enqueueTranslations() {
        let target = resolvedTarget
        guard target.languageCode != nil else { return }
        let units = viewModel.feedbackItems.flatMap {
            SourceLanguageDetector.units(for: $0, target: target)
        }
        translator.enqueue(units: units, target: target)
    }
}

