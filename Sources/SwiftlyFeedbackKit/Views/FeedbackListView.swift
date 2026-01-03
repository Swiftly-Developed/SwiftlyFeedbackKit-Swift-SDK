import SwiftUI

/// A ready-to-use view that displays a list of feedback items
public struct FeedbackListView: View {
    @StateObject private var viewModel: FeedbackListViewModel

    public init(swiftlyFeedback: SwiftlyFeedback? = nil) {
        _viewModel = StateObject(wrappedValue: FeedbackListViewModel(swiftlyFeedback: swiftlyFeedback))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.feedbackItems.isEmpty {
                    ProgressView("Loading feedback...")
                } else if viewModel.feedbackItems.isEmpty {
                    emptyState
                } else {
                    feedbackList
                }
            }
            .navigationTitle("Feedback")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingSubmitSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Picker("Filter", selection: $viewModel.selectedStatus) {
                            Text("All").tag(FeedbackStatus?.none)
                            ForEach(FeedbackStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(FeedbackStatus?.some(status))
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
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
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An error occurred")
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Feedback", systemImage: "bubble.left.and.bubble.right")
        } description: {
            Text("Be the first to submit feedback!")
        } actions: {
            Button("Submit Feedback") {
                viewModel.showingSubmitSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var feedbackList: some View {
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
final class FeedbackListViewModel: ObservableObject {
    @Published var feedbackItems: [Feedback] = []
    @Published var isLoading = false
    @Published var showingSubmitSheet = false
    @Published var showingError = false
    @Published var errorMessage: String?
    @Published var selectedStatus: FeedbackStatus? {
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
