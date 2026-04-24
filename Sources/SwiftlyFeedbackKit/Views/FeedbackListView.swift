import SwiftUI

/// A ready-to-use view that displays a list of feedback items
public struct FeedbackListView: View {
    @State private var viewModel: FeedbackListViewModel
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

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
                        .accessibilityLabel(Strings.accessibilityLoadingFeedback)
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
            .sheet(isPresented: $viewModel.showingVoteDialog) {
                ListVoteDialogView(viewModel: viewModel)
            }
        }
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
                    let cardView = FeedbackCardView(feedback: feedback) {
                        Task { await viewModel.toggleVote(for: feedback) }
                    }
                    NavigationLink(value: feedback) {
                        cardView
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(cardView.accessibilityDescription)
                    .accessibilityHint(Strings.accessibilityViewDetails)
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

struct ListVoteDialogView: View {
    @Bindable var viewModel: FeedbackListViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    #if os(iOS)
    @SwiftUI.Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
                            notify: viewModel.voteNotifyStatusChange,
                            subscribeToMailingList: viewModel.voteSubscribeToMailingList
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
            Text(Strings.voteDialogTitle)
                .font(.headline)

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

            if SwiftlyFeedback.config.showMailingListOptIn && hasValidEmail {
                Toggle(isOn: $viewModel.voteSubscribeToMailingList) {
                    Text(Strings.mailingListOptIn)
                }
            }

            Spacer()

            Divider()

            HStack {
                Button(Strings.voteDialogSkip) {
                    submitAndDismiss(email: nil, notify: false)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(Strings.voteDialogSubmit) {
                    submitAndDismiss(
                        email: viewModel.voteEmail,
                        notify: viewModel.voteNotifyStatusChange,
                        subscribeToMailingList: viewModel.voteSubscribeToMailingList
                    )
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(theme.primaryColor.resolve(for: colorScheme))
            }
        }
        .padding(20)
        .frame(width: 380, height: 300)
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
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    viewModel.voteNotifyStatusChange = false
                }
            }

            if SwiftlyFeedback.config.showMailingListOptIn && hasValidEmail {
                Toggle(isOn: $viewModel.voteSubscribeToMailingList) {
                    Text(Strings.mailingListOptIn)
                }
            }
        } footer: {
            Text(Strings.voteDialogNotifyDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func submitAndDismiss(email: String?, notify: Bool, subscribeToMailingList: Bool? = nil) {
        dismiss()

        // Save the email to config for future votes (if a valid email was provided)
        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validEmail = trimmedEmail, !validEmail.isEmpty {
            SwiftlyFeedback.config.userEmail = validEmail
        }

        guard let feedbackId = viewModel.pendingVoteFeedbackId else { return }
        viewModel.pendingVoteFeedbackId = nil

        Task {
            await viewModel.submitVote(for: feedbackId, email: email, notify: notify, subscribeToMailingList: subscribeToMailingList)
        }
    }
}

/// Sort options for the feedback list
public enum FeedbackSortOption: String, CaseIterable, Sendable {
    case votes = "Votes"
    case newest = "Newest"
    case oldest = "Oldest"
    case comments = "Comments"

    var localizedName: String {
        switch self {
        case .votes: return Strings.sortVotes
        case .newest: return Strings.sortNewest
        case .oldest: return Strings.sortOldest
        case .comments: return Strings.sortComments
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

    // Vote dialog state
    var showingVoteDialog = false
    var voteEmail = ""
    var voteNotifyStatusChange = false
    var voteSubscribeToMailingList = SwiftlyFeedback.config.mailingListDefaultOptIn
    var pendingVoteFeedbackId: UUID?

    let swiftlyFeedback: SwiftlyFeedback?

    private var loadTask: Task<Void, Never>?
    private var hasLoadedOnce = false

    init(swiftlyFeedback: SwiftlyFeedback?) {
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.shared
        self.voteNotifyStatusChange = SwiftlyFeedback.config.voteNotificationDefaultOptIn
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
                errorMessage = message ?? Strings.errorFeedbackLimitMessage
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
            case .comments:
                feedbackItems.sort { $0.commentCount > $1.commentCount }
            }
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
                await submitVote(for: feedback.id, email: configuredEmail, notify: config.voteNotificationDefaultOptIn, subscribeToMailingList: config.mailingListDefaultOptIn)
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

    func submitVote(for feedbackId: UUID, email: String?, notify: Bool, subscribeToMailingList: Bool? = nil) async {
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
                    subscribeToMailingList: validEmail != nil ? subscribeToMailingList : nil
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
