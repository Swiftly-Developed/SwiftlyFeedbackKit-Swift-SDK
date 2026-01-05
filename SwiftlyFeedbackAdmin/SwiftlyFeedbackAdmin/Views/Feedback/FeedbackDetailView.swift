import SwiftUI

struct FeedbackDetailView: View {
    let feedback: Feedback
    let apiKey: String
    let allowedStatuses: [FeedbackStatus]
    @Bindable var viewModel: FeedbackViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                headerSection

                // Merge history section (if applicable)
                if feedback.hasMergedFeedback {
                    Divider()
                    mergeHistorySection
                }

                Divider()

                // Description section
                descriptionSection

                Divider()

                // Comments section
                commentsSection
            }
            .padding()
        }
        .navigationTitle("Feedback Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    statusMenu
                    categoryMenu
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Feedback", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await viewModel.loadComments(feedbackId: feedback.id, apiKey: apiKey)
        }
        .alert("Delete Feedback", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteFeedback(id: feedback.id) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this feedback? This action cannot be undone.")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status and Category badges
            HStack(spacing: 8) {
                FeedbackStatusBadge(status: feedback.status)
                FeedbackCategoryBadge(category: feedback.category)
                MrrBadge(mrr: feedback.formattedMrr)
                if feedback.hasMergedFeedback {
                    MergeBadge(count: feedback.mergedCount)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Text("\(feedback.voteCount)")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.blue)
            }

            // Title
            Text(feedback.title)
                .font(.title2)
                .fontWeight(.bold)

            // Metadata
            VStack(alignment: .leading, spacing: 6) {
                if let email = feedback.userEmail {
                    Label(email, systemImage: "person.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(feedback.userId, systemImage: "number")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(spacing: 16) {
                    if let createdAt = feedback.createdAt {
                        Label {
                            Text("Created \(createdAt, style: .relative) ago")
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if let updatedAt = feedback.updatedAt, updatedAt != feedback.createdAt {
                        Label {
                            Text("Updated \(updatedAt, style: .relative) ago")
                        } icon: {
                            Image(systemName: "pencil")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)

            Text(feedback.description)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Merge History Section

    private var mergeHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.merge")
                    .foregroundStyle(.indigo)
                Text("Merge History")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("This feedback was created by merging \(feedback.mergedCount) other feedback items.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let mergedIds = feedback.mergedFeedbackIds {
                    Text("Merged Feedback IDs:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.tertiary)

                    ForEach(mergedIds, id: \.self) { id in
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text(id.uuidString.prefix(8) + "...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospaced()
                        }
                    }
                }
            }
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.secondarySystemGroupedBackground))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Comments")
                    .font(.headline)
                Text("(\(viewModel.comments.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Add comment input
            addCommentInput

            // Comments list
            if viewModel.isLoadingComments {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding()
            } else if viewModel.comments.isEmpty {
                noCommentsView
            } else {
                commentsList
            }
        }
    }

    private var addCommentInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // Admin avatar
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                            .font(.subheadline)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Add a comment as admin...", text: $viewModel.newCommentContent, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .onSubmit {
                            guard !viewModel.newCommentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            Task {
                                await viewModel.addComment(
                                    feedbackId: feedback.id,
                                    apiKey: apiKey,
                                    userId: "admin"
                                )
                            }
                        }

                    if !viewModel.newCommentContent.isEmpty {
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                viewModel.newCommentContent = ""
                            }
                            .buttonStyle(.bordered)

                            Button("Post Comment") {
                                Task {
                                    await viewModel.addComment(
                                        feedbackId: feedback.id,
                                        apiKey: apiKey,
                                        userId: "admin"
                                    )
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.newCommentContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .padding()
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(.secondarySystemGroupedBackground))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var noCommentsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No comments yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Be the first to respond to this feedback")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var commentsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.comments) { comment in
                CommentRowView(
                    comment: comment,
                    onDelete: {
                        Task {
                            await viewModel.deleteComment(
                                feedbackId: feedback.id,
                                commentId: comment.id,
                                apiKey: apiKey
                            )
                        }
                    }
                )
            }
        }
    }

    // MARK: - Menus

    private var statusMenu: some View {
        Menu {
            ForEach(allowedStatuses, id: \.self) { status in
                Button {
                    Task {
                        await viewModel.updateFeedbackStatus(id: feedback.id, status: status)
                    }
                } label: {
                    HStack {
                        Text(status.displayName)
                        Spacer()
                        if feedback.status == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Set Status", systemImage: "flag")
        }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(FeedbackCategory.allCases, id: \.self) { category in
                Button {
                    Task {
                        await viewModel.updateFeedbackCategory(id: feedback.id, category: category)
                    }
                } label: {
                    HStack {
                        Text(category.displayName)
                        Spacer()
                        if feedback.category == category {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Label("Set Category", systemImage: "tag")
        }
    }
}

// MARK: - Comment Row View

struct CommentRowView: View {
    let comment: Comment
    let onDelete: () -> Void
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(comment.isAdmin ? Color.blue.gradient : Color.gray.gradient)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: comment.isAdmin ? "person.fill.checkmark" : "person.fill")
                        .foregroundStyle(.white)
                        .font(.caption)
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.isAdmin ? "Admin" : comment.userId)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if comment.isAdmin {
                        Text("Staff")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let createdAt = comment.createdAt {
                        Text(createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Menu {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                }

                Text(comment.content)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(.secondarySystemGroupedBackground))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("Delete Comment", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }
}

// MARK: - Preview

#Preview("Feedback Detail") {
    NavigationStack {
        FeedbackDetailView(
            feedback: Feedback(
                id: UUID(),
                title: "Add dark mode support",
                description: "It would be great to have a dark mode option for the app. The current bright theme is hard on the eyes when using the app at night.",
                status: .inProgress,
                category: .featureRequest,
                userId: "user-123",
                userEmail: "user@example.com",
                voteCount: 42,
                hasVoted: false,
                commentCount: 3,
                totalMrr: 9.99,
                createdAt: Date().addingTimeInterval(-86400 * 3),
                updatedAt: Date().addingTimeInterval(-3600),
                mergedIntoId: nil,
                mergedAt: nil,
                mergedFeedbackIds: [UUID(), UUID()],
                githubIssueUrl: nil,
                githubIssueNumber: nil,
                clickupTaskUrl: nil,
                clickupTaskId: nil
            ),
            apiKey: "test-key",
            allowedStatuses: [.pending, .approved, .inProgress, .completed, .rejected],
            viewModel: FeedbackViewModel()
        )
    }
}
