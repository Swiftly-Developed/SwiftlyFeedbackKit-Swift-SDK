import SwiftUI

/// A ready-to-use view that displays a list of feedback items
public struct FeedbackListView: View {
    @State private var viewModel: FeedbackListViewModel
    @State private var translator = FeedbackTranslator()
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.locale) private var locale

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

    public init(swiftlyFeedback: SwiftlyFeedback? = nil) {
        _viewModel = State(wrappedValue: FeedbackListViewModel(swiftlyFeedback: swiftlyFeedback))
    }

    public var body: some View {
        #if os(macOS)
        NavigationStack {
            listColumn
        }
        #else
        // One container at every width. Compact (outer display, Slide Over) collapses
        // to the list; regular (inner display, iPad) shows the detail beside it.
        // The selection lives in this view, so folding does not rebuild the column.
        NavigationSplitView {
            listColumn
        } detail: {
            ContentUnavailableView(
                String(localized: .feedbackListTitle),
                systemImage: "bubble.left.and.bubble.right"
            )
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
                            FeedbackSearchEmptyStateView(query: viewModel.searchText) {
                                viewModel.clearSearch()
                            }
                        } else {
                            FeedbackListContentView(
                                viewModel: viewModel,
                                translator: translator,
                                target: resolvedTarget
                            )
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
                prompt: Text(String(localized: .searchPrompt))
            ) { token in
                Label(token.displayName, systemImage: token.iconName)
            }
            .navigationTitle(String(localized: .feedbackListTitle))
            .tint(theme.primaryColor == .default ? Color.primary : theme.primaryColor.resolve(for: colorScheme))
            .toolbar {
                if !viewModel.hasInvalidApiKey {
                    #if os(macOS)
                    ToolbarItem(placement: .navigation) {
                        Button(String(localized: .toolbarRefresh), systemImage: "arrow.clockwise") {
                            Task { await viewModel.loadFeedback() }
                        }
                        .disabled(viewModel.state == .loading || viewModel.isRefreshing)
                        .keyboardShortcut("r", modifiers: .command)
                        .help(String(localized: .toolbarRefresh))
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
                                Label(String(localized: .toolbarSort), systemImage: "arrow.up.arrow.down")
                            }

                            // Status filter (if enabled)
                            if config.buttons.statusFilter.display {
                                Divider()

                                Picker(selection: $viewModel.selectedStatus) {
                                    Text(String(localized: .filterAll)).tag(FeedbackStatus?.none)
                                    ForEach(FeedbackStatus.allCases, id: \.self) { status in
                                        Text(status.localizedDisplayName).tag(FeedbackStatus?.some(status))
                                    }
                                } label: {
                                    Label(String(localized: .toolbarStatus), systemImage: "line.3.horizontal.decrease.circle")
                                }
                            }

                            TranslationTargetPicker(
                                targets: orderedTargets,
                                selection: $chosenTarget,
                                displayLocale: locale
                            )
                        } label: {
                            // Authored name: the menu contains both sort and filter,
                            // so it is named for both — never a "More…"-family default.
                            Label(String(localized: .toolbarSortAndFilter), systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }

                    if config.buttons.addButton.display {
                        ToolbarItem(placement: .primaryAction) {
                            Button(String(localized: .feedbackSubmitTitle), systemImage: "plus") {
                                if config.allowFeedbackSubmission {
                                    viewModel.showingSubmitSheet = true
                                } else {
                                    viewModel.showingSubmissionDisabledAlert = true
                                }
                            }
                            .tint(theme.primaryColor.resolve(for: colorScheme))
                        }
                    }
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
            .alert(String(localized: .errorTitle), isPresented: $viewModel.showingError) {
                Button(String(localized: .errorOk), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? String(localized: .errorGeneric))
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

