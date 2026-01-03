import SwiftUI

public struct FeedbackDetailView: View {
    let feedback: Feedback
    let swiftlyFeedback: SwiftlyFeedback?
    @State private var viewModel: FeedbackDetailViewModel

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    public init(feedback: Feedback, swiftlyFeedback: SwiftlyFeedback? = nil) {
        self.feedback = feedback
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        _viewModel = State(wrappedValue: FeedbackDetailViewModel(
            feedback: feedback,
            swiftlyFeedback: swiftlyFeedback ?? SwiftlyFeedback.shared
        ))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FeedbackDetailHeaderView(feedback: feedback)
                FeedbackDetailVoteView(viewModel: viewModel)

                if config.showCommentSection {
                    FeedbackDetailCommentsView(viewModel: viewModel)
                }
            }
            .padding()
        }
        .navigationTitle(String(localized: Strings.feedbackDetailTitle))
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if config.showCommentSection {
                await viewModel.loadComments()
            }
        }
        .alert(String(localized: Strings.errorTitle), isPresented: $viewModel.showingError) {
            Button(String(localized: Strings.errorOK), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? String(localized: Strings.errorGeneric))
        }
    }
}

struct FeedbackDetailHeaderView: View {
    let feedback: Feedback

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if config.showStatusBadge {
                    StatusBadge(status: feedback.status)
                }
                if config.showCategoryBadge {
                    CategoryBadge(category: feedback.category)
                }
                Spacer()
            }

            Text(feedback.title)
                .font(.title2)
                .bold()

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
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct FeedbackDetailVoteView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.config }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    var body: some View {
        HStack {
            if config.showVoteCount {
                VoteButton(
                    voteCount: viewModel.currentFeedback.voteCount,
                    hasVoted: viewModel.currentFeedback.hasVoted
                ) {
                    Task { await viewModel.toggleVote() }
                }
            }

            Text(viewModel.currentFeedback.hasVoted
                 ? String(localized: Strings.votedButton)
                 : String(localized: Strings.voteButton))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct FeedbackDetailCommentsView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(String(localized: Strings.commentsTitle)) (\(viewModel.comments.count))")
                .font(.headline)

            if viewModel.isLoadingComments {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.comments.isEmpty {
                Text(Strings.commentsEmpty)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(viewModel.comments) { comment in
                    CommentRowView(comment: comment)
                }
            }

            HStack {
                TextField(String(localized: Strings.addCommentPlaceholder), text: $viewModel.newCommentText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    Task { await viewModel.submitComment() }
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .tint(theme.primaryColor.resolve(for: colorScheme))
                .disabled(viewModel.newCommentText.isEmpty || viewModel.isSubmittingComment)
            }
        }
        .padding()
        .background(.background.secondary)
        .clipShape(.rect(cornerRadius: 12))
    }
}

struct CommentRowView: View {
    let comment: Comment

    @Environment(\.colorScheme) private var colorScheme
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.isAdmin ? "Team" : "User")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(comment.isAdmin ? theme.primaryColor.resolve(for: colorScheme) : .secondary)

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
@Observable
final class FeedbackDetailViewModel {
    var currentFeedback: Feedback
    var comments: [Comment] = []
    var isLoadingComments = false
    var newCommentText = ""
    var isSubmittingComment = false
    var showingError = false
    var errorMessage: String?

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

        let config = SwiftlyFeedback.config

        // Check if undo vote is allowed
        if currentFeedback.hasVoted && !config.allowUndoVote {
            return
        }

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
