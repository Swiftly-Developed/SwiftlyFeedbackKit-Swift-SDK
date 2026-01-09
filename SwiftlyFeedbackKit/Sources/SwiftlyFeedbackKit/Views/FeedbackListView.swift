import SwiftUI

/// A ready-to-use view that displays a list of feedback items
public struct FeedbackListView: View {
    @State private var viewModel: FeedbackListViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    public init(swiftlyFeedback: SwiftlyFeedback? = nil) {
        _viewModel = State(wrappedValue: FeedbackListViewModel(swiftlyFeedback: swiftlyFeedback))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.hasInvalidApiKey {
                    InvalidApiKeyView()
                } else if viewModel.isLoading && viewModel.feedbackItems.isEmpty {
                    ProgressView()
                } else if viewModel.feedbackItems.isEmpty {
                    FeedbackEmptyStateView(
                        onSubmit: { viewModel.showingSubmitSheet = true },
                        onSubmitDisabled: { viewModel.showingSubmissionDisabledAlert = true }
                    )
                } else {
                    FeedbackListContentView(viewModel: viewModel)
                }
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
                        .disabled(viewModel.isLoading)
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
                            if config.buttons.segmentedControl.display {
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
                            Label(Strings.toolbarFilter, systemImage: "line.3.horizontal.decrease.circle")
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
                await viewModel.loadFeedback()
            }
            .task {
                await viewModel.loadFeedbackIfNeeded()
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
        }
    }
}

struct FeedbackEmptyStateView: View {
    let onSubmit: () -> Void
    let onSubmitDisabled: () -> Void

    @Environment(\.colorScheme) private var colorScheme
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

struct InvalidApiKeyView: View {
    var body: some View {
        ContentUnavailableView {
            Label(Strings.errorInvalidApiKeyTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(Strings.errorInvalidApiKeyMessage)
        }
    }
}

struct FeedbackListContentView: View {
    @Bindable var viewModel: FeedbackListViewModel

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.feedbackItems) { feedback in
                    NavigationLink(value: feedback) {
                        FeedbackCardView(feedback: feedback) {
                            Task { await viewModel.toggleVote(for: feedback) }
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding()
            .animation(.smooth, value: viewModel.feedbackItems)
        }
        .navigationDestination(for: Feedback.self) { feedback in
            FeedbackDetailView(feedback: feedback, swiftlyFeedback: viewModel.swiftlyFeedback)
        }
    }
}

/// Sort options for the feedback list
public enum FeedbackSortOption: String, CaseIterable, Sendable {
    case votes = "Votes"
    case newest = "Newest"
    case oldest = "Oldest"

    var localizedName: String {
        switch self {
        case .votes: return Strings.sortVotes
        case .newest: return Strings.sortNewest
        case .oldest: return Strings.sortOldest
        }
    }
}

@MainActor
@Observable
final class FeedbackListViewModel {
    var feedbackItems: [Feedback] = []
    var isLoading = false
    var showingSubmitSheet = false
    var showingError = false
    var errorMessage: String?
    var showingSubmissionDisabledAlert = false
    var hasInvalidApiKey = false
    var selectedStatus: FeedbackStatus? {
        didSet { Task { await loadFeedback() } }
    }
    var selectedSort: FeedbackSortOption = .votes {
        didSet { sortFeedback() }
    }

    let swiftlyFeedback: SwiftlyFeedback?

    private var loadTask: Task<Void, Never>?
    private var hasLoadedOnce = false

    init(swiftlyFeedback: SwiftlyFeedback?) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
    }

    func loadFeedback() async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        // Cancel any in-flight request
        loadTask?.cancel()

        isLoading = true

        let task = Task {
            do {
                try Task.checkCancellation()
                let items = try await sf.getFeedback(status: selectedStatus)
                try Task.checkCancellation()
                feedbackItems = items
                sortFeedback()
                hasLoadedOnce = true
            } catch is CancellationError {
                // Silently ignore cancellation - another request is taking over
            } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
                hasInvalidApiKey = true
            } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
                errorMessage = message ?? String(localized: Strings.errorFeedbackLimitMessage)
                showingError = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
            isLoading = false
        }

        loadTask = task
        await task.value
    }

    func loadFeedbackIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await loadFeedback()
    }

    private func sortFeedback() {
        withAnimation(.smooth) {
            switch selectedSort {
            case .votes:
                feedbackItems.sort { $0.voteCount > $1.voteCount }
            case .newest:
                feedbackItems.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            case .oldest:
                feedbackItems.sort { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            }
        }
    }

    func toggleVote(for feedback: Feedback) async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        let config = SwiftlyFeedback.config

        // Check if undo vote is allowed
        if feedback.hasVoted && !config.allowUndoVote {
            return
        }

        do {
            if feedback.hasVoted {
                _ = try await sf.unvote(for: feedback.id)
            } else {
                _ = try await sf.vote(for: feedback.id)
            }
            await loadFeedback()
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: Strings.errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
