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
        Group {
            if viewModel.hasInvalidApiKey {
                InvalidApiKeyView()
            } else {
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
            }
        }
        .navigationTitle(Strings.feedbackDetailTitle)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if config.showCommentSection {
                await viewModel.loadComments()
            }
        }
        .onAppear {
            if SwiftlyFeedback.config.enableAutomaticViewTracking {
                SwiftlyFeedback.view(.feedbackDetail, properties: ["feedbackId": feedback.id.uuidString])
            }
        }
        .alert(Strings.errorTitle, isPresented: $viewModel.showingError) {
            Button(Strings.errorOK, role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? Strings.errorGeneric)
        }
        .sheet(isPresented: $viewModel.showingVoteDialog) {
            VoteDialogView(viewModel: viewModel)
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

            // Rejection reason section (only shown when status is rejected and reason is provided)
            if feedback.status == .rejected,
               let reason = feedback.rejectionReason,
               !reason.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text(Strings.rejectionReasonTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(.red)

                    Text(reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let createdAt = feedback.createdAt {
                Text(String(format: Strings.feedbackSubmitted, createdAt.formatted(date: .abbreviated, time: .shortened)))
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

    private var themeColor: Color {
        theme.primaryColor.resolve(for: colorScheme)
    }

    private var isDisabled: Bool {
        let status = viewModel.currentFeedback.status
        let hasVoted = viewModel.currentFeedback.hasVoted
        return !status.canVote || (!config.allowUndoVote && hasVoted)
    }

    private var foregroundColor: Color {
        if !viewModel.currentFeedback.status.canVote {
            return .secondary.opacity(0.5)
        }
        return themeColor
    }

    private var backgroundColor: Color {
        if viewModel.currentFeedback.hasVoted {
            return themeColor.opacity(0.15)
        }
        return .clear
    }

    private var borderColor: Color {
        if !viewModel.currentFeedback.status.canVote {
            return .secondary.opacity(0.3)
        }
        return themeColor.opacity(0.5)
    }

    var body: some View {
        Button {
            Task { await viewModel.toggleVote() }
        } label: {
            HStack(spacing: 12) {
                if config.showVoteCount {
                    VStack(spacing: 2) {
                        Image(systemName: viewModel.currentFeedback.hasVoted ? "arrowtriangle.up.fill" : "arrowtriangle.up")
                            .font(.system(size: 14, weight: .bold))
                        Text(viewModel.currentFeedback.voteCount, format: .number)
                            .font(.system(size: 13))
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(foregroundColor)
                    .frame(width: 44, height: 44)
                }

                Text(viewModel.currentFeedback.hasVoted
                     ? Strings.votedButton
                     : Strings.voteButton)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(foregroundColor)

                Spacer()
            }
            .padding()
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct FeedbackDetailCommentsView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(Strings.commentsTitle) (\(viewModel.comments.count))")
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
                TextField(Strings.addCommentPlaceholder, text: $viewModel.newCommentText)
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
                Text(comment.isAdmin ? Strings.commentAuthorTeam : Strings.commentAuthorUser)
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

struct VoteDialogView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.theme }

    private var hasValidEmail: Bool {
        !viewModel.voteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        #if os(macOS)
        macOSContent
        #else
        iOSContent
        #endif
    }

    // MARK: - iOS & iPadOS Content

    #if !os(macOS)
    private var iOSContent: some View {
        NavigationStack {
            Form {
                emailSection
                notificationSection
            }
            .navigationTitle(Strings.voteDialogTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Strings.voteDialogSkip) {
                        submitAndDismiss(email: nil, notify: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(Strings.voteDialogSubmit) {
                        submitAndDismiss(
                            email: viewModel.voteEmail,
                            notify: viewModel.voteNotifyStatusChange
                        )
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(theme.primaryColor.resolve(for: colorScheme))
        }
        .presentationDetents(presentationDetentsForDevice)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(20)
        .interactiveDismissDisabled(false)
        .presentationSizing(.form)
    }

    private var presentationDetentsForDevice: Set<PresentationDetent> {
        // iPhone: Use height-based detent for compact content
        // iPad: .form sizing handles it, but provide medium as fallback
        if horizontalSizeClass == .compact {
            return [.height(320)]
        } else {
            return [.medium]
        }
    }
    #endif

    // MARK: - macOS Content

    #if os(macOS)
    private var macOSContent: some View {
        VStack(spacing: 16) {
            // Header
            Text(Strings.voteDialogTitle)
                .font(.headline)

            // Email field
            VStack(alignment: .leading, spacing: 6) {
                Text(Strings.voteDialogEmailHeader)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField(Strings.voteDialogEmailPlaceholder, text: $viewModel.voteEmail)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()

                Text(Strings.voteDialogEmailFooter)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Notification toggle
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $viewModel.voteNotifyStatusChange) {
                    Text(Strings.voteDialogNotifyToggle)
                }
                .disabled(!hasValidEmail)
                .onChange(of: viewModel.voteEmail) { _, newValue in
                    if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.voteNotifyStatusChange = false
                    }
                }

                Text(Strings.voteDialogNotifyDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Divider()

            // Button bar (HIG: buttons at bottom, Cancel left, Primary right)
            HStack {
                Button(Strings.voteDialogSkip) {
                    submitAndDismiss(email: nil, notify: false)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(Strings.voteDialogSubmit) {
                    submitAndDismiss(
                        email: viewModel.voteEmail,
                        notify: viewModel.voteNotifyStatusChange
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryColor.resolve(for: colorScheme))
            }
        }
        .padding(20)
        .frame(width: 380, height: 280)
    }
    #endif

    // MARK: - Shared Sections

    private var emailSection: some View {
        Section {
            TextField(Strings.voteDialogEmailPlaceholder, text: $viewModel.voteEmail)
                .textContentType(.emailAddress)
                #if !os(macOS)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
        } header: {
            Text(Strings.voteDialogEmailHeader)
        } footer: {
            Text(Strings.voteDialogEmailFooter)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle(isOn: $viewModel.voteNotifyStatusChange) {
                Text(Strings.voteDialogNotifyToggle)
            }
            .disabled(!hasValidEmail)
            .onChange(of: viewModel.voteEmail) { _, newValue in
                // Auto-disable notification if email is cleared
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.voteNotifyStatusChange = false
                }
            }
        } footer: {
            Text(Strings.voteDialogNotifyDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func submitAndDismiss(email: String?, notify: Bool) {
        dismiss()

        // Save the email to config for future votes (if a valid email was provided)
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validEmail = trimmedEmail, !validEmail.isEmpty {
            SwiftlyFeedback.config.userEmail = validEmail
        }

        Task {
            await viewModel.submitVote(email: email, notify: notify)
        }
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
    var hasInvalidApiKey = false

    // Vote dialog state
    var showingVoteDialog = false
    var voteEmail = ""
    var voteNotifyStatusChange = false

    private let swiftlyFeedback: SwiftlyFeedback?

    init(feedback: Feedback, swiftlyFeedback: SwiftlyFeedback?) {
        self.currentFeedback = feedback
        self.swiftlyFeedback = swiftlyFeedback
        self.voteNotifyStatusChange = SwiftlyFeedback.config.voteNotificationDefaultOptIn
    }

    func loadComments() async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        isLoadingComments = true
        defer { isLoadingComments = false }

        do {
            comments = try await sf.getComments(for: currentFeedback.id)
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

    func toggleVote() async {
        guard swiftlyFeedback != nil else { return }
        guard !hasInvalidApiKey else { return }

        let config = SwiftlyFeedback.config

        if currentFeedback.hasVoted {
            // Unvoting - no dialog needed
            if !config.allowUndoVote { return }
            await submitVote(email: nil, notify: false)
        } else {
            // Check if userEmail is already configured
            let configuredEmail = config.userEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
            let hasConfiguredEmail = configuredEmail?.isEmpty == false

            if hasConfiguredEmail {
                // Use configured email directly, no dialog needed
                await submitVote(email: configuredEmail, notify: config.voteNotificationDefaultOptIn)
            } else if config.showVoteEmailField {
                // No configured email - show dialog to collect email
                voteEmail = ""
                voteNotifyStatusChange = config.voteNotificationDefaultOptIn
                showingVoteDialog = true
            } else {
                // No email configured and dialog disabled - vote without email
                await submitVote(email: nil, notify: false)
            }
        }
    }

    func submitVote(email: String?, notify: Bool) async {
        guard let sf = swiftlyFeedback else { return }
        guard !hasInvalidApiKey else { return }

        do {
            let result: VoteResult
            if currentFeedback.hasVoted {
                result = try await sf.unvote(for: currentFeedback.id)
            } else {
                let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
                let validEmail = (trimmedEmail?.isEmpty == false) ? trimmedEmail : nil
                result = try await sf.vote(
                    for: currentFeedback.id,
                    email: validEmail,
                    notifyStatusChange: notify && validEmail != nil
                )
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
                updatedAt: currentFeedback.updatedAt,
                mergedIntoId: currentFeedback.mergedIntoId,
                mergedAt: currentFeedback.mergedAt,
                mergedFeedbackIds: currentFeedback.mergedFeedbackIds,
                rejectionReason: currentFeedback.rejectionReason
            )
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

    func submitComment() async {
        guard let sf = swiftlyFeedback, !newCommentText.isEmpty else { return }
        guard !hasInvalidApiKey else { return }

        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let comment = try await sf.addComment(to: currentFeedback.id, content: newCommentText)
            comments.append(comment)
            newCommentText = ""
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
