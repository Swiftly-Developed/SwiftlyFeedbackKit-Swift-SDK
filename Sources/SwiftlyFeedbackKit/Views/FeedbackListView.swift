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
                if viewModel.isLoading && viewModel.feedbackItems.isEmpty {
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
            .navigationTitle(String(localized: Strings.feedbackListTitle))
            .toolbar {
                #if os(macOS)
                ToolbarItem(placement: .navigation) {
                    Button {
                        Task { await viewModel.loadFeedback() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh")
                }
                #endif

                if config.buttons.segmentedControl.display {
                    ToolbarItem(placement: .automatic) {
                        Menu {
                            Picker("Filter", selection: $viewModel.selectedStatus) {
                                Text("All").tag(FeedbackStatus?.none)
                                ForEach(FeedbackStatus.allCases, id: \.self) { status in
                                    Text(status.displayName).tag(FeedbackStatus?.some(status))
                                }
                            }
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
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
            .alert(String(localized: Strings.feedbackSubmissionDisabledTitle), isPresented: $viewModel.showingSubmissionDisabledAlert) {
                Button(String(localized: Strings.errorOK), role: .cancel) {}
            } message: {
                Text(config.feedbackSubmissionDisabledMessage ?? String(localized: Strings.feedbackSubmissionDisabledMessage))
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
                await viewModel.loadFeedback()
            }
            .onAppear {
                if SwiftlyFeedback.config.enableAutomaticViewTracking {
                    SwiftlyFeedback.view(.feedbackList)
                }
            }
            .alert(String(localized: Strings.errorTitle), isPresented: $viewModel.showingError) {
                Button(String(localized: Strings.errorOK), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? String(localized: Strings.errorGeneric))
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
            Label(String(localized: Strings.feedbackListEmpty), systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text(Strings.feedbackListEmptyDescription)
        } actions: {
            Button(String(localized: Strings.submitFeedbackTitle)) {
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

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    var body: some View {
        List(viewModel.feedbackItems) { feedback in
            NavigationLink(value: feedback) {
                FeedbackRowView(feedback: feedback) {
                    Task { await viewModel.toggleVote(for: feedback) }
                }
            }
        }
        .navigationDestination(for: Feedback.self) { feedback in
            FeedbackDetailView(feedback: feedback, swiftlyFeedback: viewModel.swiftlyFeedback)
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
    var selectedStatus: FeedbackStatus? {
        didSet { Task { await loadFeedback() } }
    }

    let swiftlyFeedback: SwiftlyFeedback?

    init(swiftlyFeedback: SwiftlyFeedback?) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
    }

    func loadFeedback() async {
        guard let sf = swiftlyFeedback else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            feedbackItems = try await sf.getFeedback(status: selectedStatus)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    func toggleVote(for feedback: Feedback) async {
        guard let sf = swiftlyFeedback else { return }

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
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
