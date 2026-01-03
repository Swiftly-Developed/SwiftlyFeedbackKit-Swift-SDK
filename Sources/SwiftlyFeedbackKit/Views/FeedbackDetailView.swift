import SwiftUI

public struct FeedbackDetailView: View {
    let feedback: Feedback
    let swiftlyFeedback: SwiftlyFeedback?
    @StateObject private var viewModel: FeedbackDetailViewModel

    public init(feedback: Feedback, swiftlyFeedback: SwiftlyFeedback? = nil) {
        self.feedback = feedback
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        _viewModel = StateObject(wrappedValue: FeedbackDetailViewModel(
            feedback: feedback,
            swiftlyFeedback: swiftlyFeedback ?? SwiftlyFeedback.shared
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        StatusBadge(status: feedback.status)
                        CategoryBadge(category: feedback.category)
                        Spacer()
                    }

                    Text(feedback.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(feedback.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    if let createdAt = feedback.createdAt {
                        Text("Submitted \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Vote section
                HStack {
                    VoteButton(
                        voteCount: viewModel.currentFeedback.voteCount,
                        hasVoted: viewModel.currentFeedback.hasVoted
                    ) {
                        Task { await viewModel.toggleVote() }
                    }

                    Text(viewModel.currentFeedback.hasVoted ? "You voted for this" : "Vote for this feature")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Comments section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comments (\(viewModel.comments.count))")
                        .font(.headline)

                    if viewModel.isLoadingComments {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if viewModel.comments.isEmpty {
                        Text("No comments yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(viewModel.comments) { comment in
                            CommentRow(comment: comment)
                        }
                    }

                    // Add comment
                    HStack {
                        TextField("Add a comment...", text: $viewModel.newCommentText)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            Task { await viewModel.submitComment() }
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(viewModel.newCommentText.isEmpty || viewModel.isSubmittingComment)
                    }
                }
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadComments()
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }
}

struct CommentRow: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.isAdmin ? "Team" : "User")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(comment.isAdmin ? .blue : .secondary)

                if let createdAt = comment.createdAt {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Text(comment.content)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
final class FeedbackDetailViewModel: ObservableObject {
    @Published var currentFeedback: Feedback
    @Published var comments: [Comment] = []
    @Published var isLoadingComments = false
    @Published var newCommentText = ""
    @Published var isSubmittingComment = false
    @Published var showingError = false
    @Published var errorMessage: String?

    private let swiftlyFeedback: SwiftlyFeedback?

    init(feedback: Feedback, swiftlyFeedback: SwiftlyFeedback?) {
        self.currentFeedback = feedback
        self.swiftlyFeedback = swiftlyFeedback
    }

    func loadComments() async {
        guard let sf = swiftlyFeedback else { return }

        isLoadingComments = true
        defer { isLoadingComments = false }

        do {
            comments = try await sf.getComments(for: currentFeedback.id)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    func toggleVote() async {
        guard let sf = swiftlyFeedback else { return }

        do {
            let result: VoteResult
            if currentFeedback.hasVoted {
                result = try await sf.unvote(for: currentFeedback.id)
            } else {
                result = try await sf.vote(for: currentFeedback.id)
            }

            currentFeedback = Feedback(
                id: currentFeedback.id,
                title: currentFeedback.title,
                description: currentFeedback.description,
                status: currentFeedback.status,
                category: currentFeedback.category,
                userId: currentFeedback.userId,
                userEmail: currentFeedback.userEmail,
                voteCount: result.voteCount,
                hasVoted: result.hasVoted,
                commentCount: currentFeedback.commentCount,
                createdAt: currentFeedback.createdAt,
                updatedAt: currentFeedback.updatedAt
            )
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    func submitComment() async {
        guard let sf = swiftlyFeedback, !newCommentText.isEmpty else { return }

        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let comment = try await sf.addComment(to: currentFeedback.id, content: newCommentText)
            comments.append(comment)
            newCommentText = ""
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
