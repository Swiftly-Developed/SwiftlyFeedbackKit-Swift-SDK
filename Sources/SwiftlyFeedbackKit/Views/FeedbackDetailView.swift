import SwiftUI

public struct FeedbackDetailView: View {
    let feedback: Feedback
    let swiftlyFeedback: SwiftlyFeedback?
    let onModerationChange: (ModerationBoardEvent) -> Void
    @State private var viewModel: FeedbackDetailViewModel
    @State private var translator = FeedbackTranslator()
    @SwiftUI.Environment(\.locale) private var locale
    @SwiftUI.Environment(\.colorScheme) private var colorScheme
    @SwiftUI.Environment(\.dismiss) private var dismiss

    // This surface reads the reader's choice and never offers a control of its own:
    // two controls for one preference is two places to disagree (TRANSLATION01 §14.2).
    // The state is the control-owning surface's, unchanged, minus the persist arm.
    @State private var supportedTargets: [Locale.Language] = []
    @State private var chosenTarget: Locale.Language?     // nil == follow the device
    private let targetStore = TranslationTargetStore()
    #if os(macOS)
    /// Comments live in a trailing inspector as a group chat, like the Admin app.
    @State private var showingComments = true
    #endif

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }

    /// Toolbar and controls use the system label color unless the host set a theme color.
    private var controlTint: Color {
        let theme = SwiftlyFeedback.appearance
        if theme.primaryColor == .default {
            return .primary
        }
        return theme.primaryColor.resolve(for: colorScheme)
    }

    /// What every derivation site on this surface reads. Held in view state rather than
    /// re-read from the preference store on each evaluation, because SwiftUI has no
    /// dependency on that store and would therefore never re-evaluate this surface for a
    /// choice made by a control on another one.
    private var resolvedTarget: Locale.Language {
        chosenTarget ?? locale.language
    }

    public init(
        feedback: Feedback,
        swiftlyFeedback: SwiftlyFeedback? = nil,
        onModerationChange: @escaping (ModerationBoardEvent) -> Void = { _ in }
    ) {
        self.feedback = feedback
        self.swiftlyFeedback = swiftlyFeedback ?? SwiftlyFeedback.current
        self.onModerationChange = onModerationChange
        _viewModel = State(wrappedValue: FeedbackDetailViewModel(
            feedback: feedback,
            swiftlyFeedback: swiftlyFeedback ?? SwiftlyFeedback.current
        ))
    }

    public var body: some View {
        Group {
            if viewModel.hasInvalidApiKey {
                InvalidApiKeyView()
            } else {
                #if os(macOS)
                macOSBody
                #else
                List {
                    FeedbackDetailHeaderView(
                        feedback: feedback,
                        translatedTitle: headerProjection.title,
                        translatedDescription: headerProjection.description,
                        translatedRejectionReason: headerProjection.rejectionReason,
                        translationSourceName: headerProjection.sourceName,
                        isShowingOriginal: isShowingOriginalHeader,
                        onToggleTranslation: {
                            viewModel.toggleShowOriginal(viewModel.currentFeedback.id)
                        },
                        translationTargetName: headerProjection.targetName,
                        vote: FeedbackDetailVoteView(viewModel: viewModel)
                    )

                    if config.showCommentSection {
                        FeedbackDetailCommentsView(
                            viewModel: viewModel,
                            translator: translator,
                            target: resolvedTarget,
                            onCommenterBlocked: { onModerationChange(.blockedCommenter) }
                        )
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #else
                .listStyle(.insetGrouped)
                #endif
                .refreshable {
                    if config.showCommentSection {
                        await viewModel.refreshComments()
                    }
                }
                #endif
            }
        }
        .navigationTitle(displayedTitle)
        .tint(controlTint)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: "\(displayedTitle)\n\n\(displayedDescription)") {
                    Label(String(localized: .toolbarShare), systemImage: "square.and.arrow.up")
                }
                .help(String(localized: .toolbarShare))
            }
            if ModerationMenuVisibility.isVisible(
                authorUserId: feedback.userId,
                currentUserId: UserIdentifier.getCurrentUserId()
            ) {
                ToolbarItem(placement: .primaryAction) {
                    ContentModerationMenu(
                        onReport: { reason in
                            Task { await viewModel.reportCurrent(reason: reason) }
                        },
                        onBlock: {
                            Task {
                                let blocked = await viewModel.blockAuthor()
                                guard blocked else { return }
                                onModerationChange(.blockedAuthor)
                                dismiss()
                            }
                        }
                    )
                }
            }
            #if os(macOS)
            if config.showCommentSection {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingComments.toggle()
                    } label: {
                        Label(
                            String(localized: .commentsCount(viewModel.comments.count)),
                            systemImage: "bubble.left.and.bubble.right"
                        )
                    }
                    .help(String(localized: .commentsCount(viewModel.comments.count)))
                }
                ToolbarItem(placement: .automatic) {
                    Button(String(localized: .toolbarRefresh), systemImage: "arrow.clockwise") {
                        Task { await viewModel.refreshComments() }
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help(String(localized: .toolbarRefresh))
                }
            }
            #endif
        }
        .task {
            if config.showCommentSection {
                await viewModel.loadComments()
            }
        }
        .feedbackTranslationTask(translator)
        .onChange(of: viewModel.currentFeedback, initial: true) {
            enqueueTranslations()
        }
        .onChange(of: viewModel.comments) {
            enqueueTranslations()
        }
        .task {
            // A second task, deliberately not merged into the comment fetch above: the
            // supported set is awaited from the translation framework and its latency is
            // unbounded, so merging would serialise that fetch behind it.
            //
            // Seeding here is sufficient on this surface and no listener is needed. The
            // SDK has exactly one control, in the list's toolbar; this screen is a
            // navigation push, so the control cannot be operated while it is on screen,
            // and a fresh push re-runs this task.
            supportedTargets = await translator.supportedTargets()
            chosenTarget = targetStore.storedTarget(in: supportedTargets)
        }
        .onChange(of: resolvedTarget) {
            // The target moved, so every cached projection is stale: drop them all, then
            // re-detect and re-enqueue against the new one. This is the device-locale arm
            // it replaces, widened — the resolved target already depends on the
            // environment locale.
            translator.invalidateAll()
            enqueueTranslations()
        }
        .onAppear {
            if SwiftlyFeedback.configuration.enableAutomaticViewTracking {
                SwiftlyFeedback.view(.feedbackDetail, properties: ["feedbackId": feedback.id.uuidString])
            }
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
                Task {
                    await viewModel.submitVote(
                        email: email,
                        notify: notify,
                        subscribeToMailingList: subscribeToMailingList,
                        mailingListEmailTypes: mailingListEmailTypes
                    )
                }
            }
        }
    }

    #if os(macOS)
    /// macOS: the request reads as a document on the leading side and the conversation
    /// sits in a trailing inspector, the same layout as the Admin app's detail.
    private var macOSBody: some View {
        ScrollView {
            FeedbackDetailHeaderView(
                feedback: viewModel.currentFeedback,
                translatedTitle: headerProjection.title,
                translatedDescription: headerProjection.description,
                translatedRejectionReason: headerProjection.rejectionReason,
                translationSourceName: headerProjection.sourceName,
                isShowingOriginal: isShowingOriginalHeader,
                onToggleTranslation: {
                    viewModel.toggleShowOriginal(viewModel.currentFeedback.id)
                },
                translationTargetName: headerProjection.targetName,
                vote: FeedbackDetailVoteView(viewModel: viewModel)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .inspector(isPresented: Binding(
            get: { config.showCommentSection && showingComments },
            set: { showingComments = $0 }
        )) {
            FeedbackDetailChatView(
                viewModel: viewModel,
                translator: translator,
                target: resolvedTarget,
                onCommenterBlocked: { onModerationChange(.blockedCommenter) }
            )
            .inspectorColumnWidth(min: 300, ideal: 380, max: 560)
        }
    }
    #endif

    /// Whether the header (title + description + rejection reason together — one
    /// toggle governs all three) is showing its original-language text.
    private var isShowingOriginalHeader: Bool {
        viewModel.showOriginalIDs.contains(viewModel.currentFeedback.id)
    }

    /// The header's translation inputs: cached projections plus the localized source-
    /// and target-language names. All `nil` (affordance absent, original text stands)
    /// until the cache fills, and when the source language has no localized display
    /// name — a raw code is never shown.
    ///
    /// `targetName` is `nil` whenever the target IS the device language, which selects
    /// the existing one-argument affordance copy: naming the obvious target adds nothing.
    private var headerProjection: (
        title: String?, description: String?, rejectionReason: String?,
        sourceName: String?, targetName: String?
    ) {
        let item = viewModel.currentFeedback
        let target = resolvedTarget
        let title = translator.translation(
            for: item.id, field: .title, target: target, sourceText: item.title
        )
        let description = translator.translation(
            for: item.id, field: .description, target: target, sourceText: item.description
        )
        let rejectionReason = item.rejectionReason.flatMap {
            translator.translation(for: item.id, field: .rejectionReason, target: target, sourceText: $0)
        }
        guard title != nil || description != nil || rejectionReason != nil else {
            return (nil, nil, nil, nil, nil)
        }
        let source = SourceLanguageDetector.detect(item.description)
            ?? SourceLanguageDetector.detect(item.title)
        guard let sourceName = source?.localizedDisplayName(in: locale) else {
            return (nil, nil, nil, nil, nil)
        }
        // The same predicate the pipeline uses to decide "no translation needed", so
        // "the target is the device language" means the same thing on both sides.
        let targetName: String? = target.isSameLanguage(as: locale.language)
            ? nil
            : target.localizedTargetName(in: locale)
        return (title, description, rejectionReason, sourceName, targetName)
    }

    /// The navigation title uses the same projection as the header's title text.
    private var displayedTitle: String {
        if !isShowingOriginalHeader, headerProjection.sourceName != nil,
           let translated = headerProjection.title {
            return translated
        }
        return viewModel.currentFeedback.title
    }

    /// The description currently on screen, matching the header toggle.
    private var displayedDescription: String {
        if !isShowingOriginalHeader, headerProjection.sourceName != nil,
           let translated = headerProjection.description {
            return translated
        }
        return viewModel.currentFeedback.description
    }

    /// Detects source languages per field for the feedback and its comments and
    /// queues the uncached remainder toward the reader's resolved target. Skipped
    /// entirely when that target carries no language code.
    private func enqueueTranslations() {
        let target = resolvedTarget
        guard target.languageCode != nil else { return }
        var units = SourceLanguageDetector.units(for: viewModel.currentFeedback, target: target)
        units += viewModel.comments.compactMap {
            SourceLanguageDetector.unit(for: $0, target: target)
        }
        translator.enqueue(units: units, target: target)
    }
}

struct FeedbackDetailHeaderView<Vote: View>: View {
    let feedback: Feedback
    /// Translated projections, `nil` when no translation is cached (defaults keep
    /// existing call sites source-compatible). One affordance below the description
    /// governs title, description, and rejection reason together.
    var translatedTitle: String? = nil
    var translatedDescription: String? = nil
    var translatedRejectionReason: String? = nil
    /// Localized source-language name; `nil` means the affordance is absent.
    var translationSourceName: String? = nil
    var isShowingOriginal: Bool = false
    var onToggleTranslation: (() -> Void)? = nil
    /// Localized name of the reader's chosen target language; `nil` when that target IS
    /// the device language, which keeps the existing one-argument copy.
    var translationTargetName: String? = nil
    /// The vote control, trailing in this card the way the Showcase footer places its capsule.
    var vote: Vote

    @ScaledMetric(relativeTo: .body) private var voteSpacing: CGFloat = 12

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }

    private var displayedTitle: String {
        if !isShowingOriginal, let translatedTitle { return translatedTitle }
        return feedback.title
    }

    private var displayedDescription: String {
        if !isShowingOriginal, let translatedDescription { return translatedDescription }
        return feedback.description
    }

    private func displayedRejectionReason(_ reason: String) -> String {
        if !isShowingOriginal, let translatedRejectionReason { return translatedRejectionReason }
        return reason
    }

    var body: some View {
        #if os(macOS)
        macOSHeader
        #else
        listHeader
        #endif
    }

    #if os(macOS)
    /// Title first, the vote on its trailing edge; status, category and date as one
    /// line of facts under it, then the description.
    private var macOSHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: voteSpacing) {
                Text(displayedTitle)
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                vote
            }

            HStack(alignment: .firstTextBaseline, spacing: 14) {
                if config.showStatusBadge {
                    FeedbackStatusEyebrowView(status: feedback.status)
                }
                if config.showCategoryBadge {
                    Label(feedback.category.localizedDisplayName, systemImage: feedback.category.iconName)
                        .labelStyle(FeedbackShowcaseBaselineLabelStyle())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let createdAt = feedback.createdAt {
                    Text(String(localized: .feedbackDetailSubmitted(createdAt.formatted(date: .abbreviated, time: .shortened))))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Divider()
                .padding(.vertical, 2)

            Text(displayedDescription)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let translationSourceName, let onToggleTranslation {
                TranslationAffordanceView(
                    sourceLanguageName: translationSourceName,
                    targetLanguageName: translationTargetName,
                    isShowingOriginal: isShowingOriginal,
                    onToggle: onToggleTranslation
                )
            }

            if feedback.status == .rejected,
               let reason = feedback.rejectionReason,
               !reason.isEmpty {
                FeedbackDetailRejectionReason(reason: displayedRejectionReason(reason))
            }
        }
    }
    #endif

    private var listHeader: some View {
        Section {
            if config.showStatusBadge {
                FeedbackDetailStatusRow(status: feedback.status)
            }
            if config.showCategoryBadge {
                FeedbackDetailCategoryRow(category: feedback.category)
            }

            Text(displayedTitle)
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(displayedDescription)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let translationSourceName, let onToggleTranslation {
                TranslationAffordanceView(
                    sourceLanguageName: translationSourceName,
                    targetLanguageName: translationTargetName,
                    isShowingOriginal: isShowingOriginal,
                    onToggle: onToggleTranslation
                )
            }

            if feedback.status == .rejected,
               let reason = feedback.rejectionReason,
               !reason.isEmpty {
                FeedbackDetailRejectionReason(reason: displayedRejectionReason(reason))
            }

            // Date on the leading side, vote on the trailing side, one row of this card.
            // A separate section was a nearly empty card of its own.
            FeedbackShowcaseRowOrStackLayout(
                horizontalSpacing: voteSpacing,
                verticalSpacing: voteSpacing,
                pinsLastToTrailingEdge: true
            ) {
                if let createdAt = feedback.createdAt {
                    SystemLabel(
                        text: String(localized: .feedbackDetailSubmitted(createdAt.formatted(date: .abbreviated, time: .shortened)))
                    )
                }
                vote
            }
        }
    }
}

private struct FeedbackDetailStatusRow: View {
    let status: FeedbackStatus

    var body: some View {
        LabeledContent(String(localized: .toolbarStatus)) {
            Text(status.localizedDisplayName)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

private struct FeedbackDetailCategoryRow: View {
    let category: FeedbackCategory

    var body: some View {
        LabeledContent(String(localized: .feedbackFormCategory)) {
            Text(category.localizedDisplayName)
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

private struct FeedbackDetailRejectionReason: View {
    let reason: String

    var body: some View {
        VStack(alignment: .leading) {
            Label {
                Text(String(localized: .rejectionReasonTitle))
            } icon: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
            .bold()
            .foregroundStyle(.primary)
            Text(reason)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
    }
}

struct FeedbackDetailVoteView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var config: SwiftlyFeedbackConfiguration { SwiftlyFeedback.configuration }
    private var theme: SwiftlyFeedbackTheme { SwiftlyFeedback.appearance }

    private var themeColor: Color {
        theme.primaryColor.resolve(for: colorScheme)
    }

    private var feedback: Feedback { viewModel.currentFeedback }

    private var isDisabled: Bool {
        !feedback.status.canVote || (!config.allowUndoVote && feedback.hasVoted)
    }

    var body: some View {
        // The parent row pins this to the trailing edge. The count is a system label
        // so it scales. The Showcase capsule's button style does not, once that
        // button is the audited row.
        Group {
            #if os(macOS)
            // The same capsule as the list rows, so a request's vote looks the same
            // in both places.
            FeedbackShowcaseVoteCapsule(
                feedbackID: feedback.id,
                voteCount: feedback.voteCount,
                presentation: VotePresentation.resolve(for: feedback, isPlaceholder: false, configuration: config),
                tint: themeColor,
                action: { Task { await viewModel.toggleVote() } }
            )
            #else
            if config.showVoteCount {
                VoteButton(
                    voteCount: feedback.voteCount,
                    hasVoted: feedback.hasVoted,
                    status: feedback.status,
                    action: { Task { await viewModel.toggleVote() } }
                )
            } else {
                Button {
                    Task { await viewModel.toggleVote() }
                } label: {
                    Text(feedback.hasVoted ? String(localized: .buttonVoted) : String(localized: .buttonVote))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(theme.primaryColor == .default ? .primary : themeColor)
                .disabled(isDisabled)
                .accessibilityLabel(visibleVoteLabel)
                .accessibilityInputLabels([
                    visibleVoteLabel,
                    String(localized: feedback.hasVoted ? .buttonVoted : .buttonVote)
                ])
                .accessibilityValue(feedback.hasVoted ? String(localized: .accessibilityVoted) : String(localized: .accessibilityNotVoted))
                .accessibilityHint(
                    !feedback.status.canVote
                        ? String(localized: .accessibilityVotingClosed)
                        : VotePresentation.resolve(
                            showVoteCount: true,
                            isPlaceholder: false,
                            canVote: true,
                            hasVoted: feedback.hasVoted,
                            allowUndoVote: config.allowUndoVote
                        ).accessibilityHint?.localizedText ?? ""
                )
            }
            #endif
        }
    }

    /// The string actually drawn on the button. Voice Control shows this name.
    private var visibleVoteLabel: String {
        if config.showVoteCount {
            return feedback.voteCount.formatted(.number)
        }
        return String(localized: feedback.hasVoted ? .buttonVoted : .buttonVote)
    }
}

struct FeedbackDetailCommentsView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    let translator: FeedbackTranslator
    /// The reader's resolved target, handed down rather than re-derived: this view
    /// enqueues nothing and only reads cached projections, so a seam of its own would
    /// mean a second independently-timed answer and a render disagreeing with its parent.
    let target: Locale.Language
    /// The list reloads so the blocked person's posts leave the board.
    var onCommenterBlocked: () -> Void = {}
    @SwiftUI.Environment(\.locale) private var locale

    /// A comment row's translation inputs: the cached projection plus the localized
    /// source- and target-language names. All `nil` (affordance absent, original text
    /// stands) until the cache fills, and when the source language has no localized
    /// display name — a raw code is never shown.
    ///
    /// `targetName` is `nil` whenever the target IS the device language, which selects
    /// the existing one-argument affordance copy: naming the obvious target adds nothing.
    private func translationProjection(
        for comment: Comment
    ) -> (text: String?, sourceName: String?, targetName: String?) {
        guard let text = translator.translation(
            for: comment.id, field: .commentText, target: target, sourceText: comment.content
        ) else {
            return (nil, nil, nil)
        }
        guard let sourceName = SourceLanguageDetector.detect(comment.content)?
            .localizedDisplayName(in: locale) else {
            return (nil, nil, nil)
        }
        // The same predicate the pipeline uses to decide "no translation needed", so
        // "the target is the device language" means the same thing on both sides.
        let targetName: String? = target.isSameLanguage(as: locale.language)
            ? nil
            : target.localizedTargetName(in: locale)
        return (text, sourceName, targetName)
    }

    /// Placeholder comment for the loading skeleton: plausible metrics (a
    /// one-line author row and a body long enough to wrap), never rendered
    /// legibly — always redacted. Same pattern as `FeedbackCardSkeletonView`.
    private static let placeholder = Comment(
        id: UUID(),
        content: "Placeholder comment body that is long enough to wrap onto a second line at typical widths.",
        userId: "placeholder",
        isAdmin: false,
        createdAt: nil
    )

    var body: some View {
        Section {
            if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                ForEach(0..<3, id: \.self) { _ in
                    CommentRowView(comment: Self.placeholder)
                }
                .redacted(reason: .placeholder)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: .accessibilityLoadingComments))
            } else if viewModel.comments.isEmpty && viewModel.hasLoadedCommentsOnce {
                CommentsEmptyStateView()
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if !viewModel.comments.isEmpty {
                ForEach(viewModel.comments) { comment in
                    let projection = translationProjection(for: comment)
                    HStack(alignment: .top, spacing: 8) {
                        CommentRowView(
                            comment: comment,
                            translatedText: projection.text,
                            translationSourceName: projection.sourceName,
                            isShowingOriginal: viewModel.showOriginalIDs.contains(comment.id),
                            onToggleTranslation: { viewModel.toggleShowOriginal(comment.id) },
                            translationTargetName: projection.targetName,
                            currentUserId: UserIdentifier.getCurrentUserId()
                        )
                        if ModerationMenuVisibility.isVisible(
                            authorUserId: comment.userId,
                            currentUserId: UserIdentifier.getCurrentUserId()
                        ) {
                            ContentModerationMenu(
                                onReport: { reason in
                                    Task { await viewModel.report(comment, reason: reason) }
                                },
                                onBlock: {
                                    Task {
                                        let blocked = await viewModel.block(commenterUserId: comment.userId)
                                        guard blocked else { return }
                                        onCommenterBlocked()
                                    }
                                }
                            )
                        }
                    }
                }
            }
        } header: {
            // Footnote secondary label, no fill. A SwiftUI `Text` header is flagged as
            // only partly supporting Dynamic Type, and an opaque system background draws
            // a white box on the grouped grey.
            SystemLabel(
                text: String(localized: .commentsCount(viewModel.comments.count)),
                textStyle: .footnote,
                showsBackground: false,
                usesSecondaryLabel: true
            )
        }

        Section {
            FeedbackDetailCommentComposer(viewModel: viewModel)
        }
    }
}

private struct FeedbackDetailCommentComposer: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var themeColor: Color {
        SwiftlyFeedback.appearance.primaryColor.resolve(for: colorScheme)
    }

    private var canSubmit: Bool {
        !viewModel.newCommentText.isEmpty && !viewModel.isSubmittingComment
    }

    var body: some View {
        TextField(String(localized: .feedbackDetailCommentsAdd), text: $viewModel.newCommentText, axis: .vertical)
            .lineLimit(1...5)
            #if os(macOS)
            .textFieldStyle(.roundedBorder)
            #endif
            .submitLabel(.send)
            .onSubmit(submit)
            .onKeyPress(.return) {
                guard canSubmit else { return .ignored }
                submit()
                return .handled
            }

        Button(action: submit) {
            if viewModel.isSubmittingComment {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(String(localized: .accessibilityPostComment))
            }
        }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(SwiftlyFeedback.appearance.primaryColor == .default ? Color.primary : themeColor)
            .disabled(!canSubmit)
            .accessibilityLabel(String(localized: .accessibilityPostComment))
    }

    private func submit() {
        guard canSubmit else { return }
        viewModel.isSubmittingComment = true
        Task { await viewModel.submitComment() }
    }
}

struct CommentRowView: View {
    let comment: Comment
    /// Translated projection, `nil` when no translation is cached (defaults keep
    /// existing call sites — including the skeleton placeholder — source-compatible).
    var translatedText: String? = nil
    /// Localized source-language name; `nil` means the affordance is absent.
    var translationSourceName: String? = nil
    var isShowingOriginal: Bool = false
    var onToggleTranslation: (() -> Void)? = nil
    /// Localized name of the reader's chosen target language; `nil` when that target IS
    /// the device language, which keeps the existing one-argument copy.
    var translationTargetName: String? = nil
    /// The signed-in SDK user. Matching `comment.userId` renders Me.
    var currentUserId: String? = nil

    private var displayedContent: String {
        if !isShowingOriginal, let translatedText { return translatedText }
        return comment.content
    }

    private var authorLabel: String {
        switch CommentAuthorRole.resolve(
            commentUserId: comment.userId,
            isAdmin: comment.isAdmin,
            currentUserId: currentUserId
        ) {
        case .me:
            String(localized: .commentAuthorMe)
        case .admin:
            String(localized: .commentAuthorAdmin)
        case .user:
            String(localized: .commentAuthorUser)
        }
    }

    var body: some View {
        let row = VStack(alignment: .leading, spacing: 4) {
            HStack {
                SystemLabel(
                    text: authorLabel,
                    textStyle: .headline
                )

                if let createdAt = comment.createdAt {
                    SystemLabel(text: "·")
                    SystemLabel(text: createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            SystemLabel(text: displayedContent)

            if let translationSourceName, let onToggleTranslation {
                TranslationAffordanceView(
                    sourceLanguageName: translationSourceName,
                    targetLanguageName: translationTargetName,
                    isShowingOriginal: isShowingOriginal,
                    onToggle: onToggleTranslation
                )
            }
        }
        .padding(.vertical, 4)

        // `.combine` folds the affordance's button into the row, the same way
        // the list's `.ignore` does. Re-expose the toggle only when it is mounted.
        if let onToggleTranslation, translationSourceName != nil {
            row.accessibilityAction(
                named: isShowingOriginal
                    ? String(localized: .translationShowTranslation)
                    : String(localized: .translationShowOriginal)
            ) {
                onToggleTranslation()
            }
        } else {
            row
        }
    }
}

@MainActor
@Observable
final class FeedbackDetailViewModel {
    var currentFeedback: Feedback
    var comments: [Comment] = []
    var isLoadingComments = false
    /// True once a comments fetch has completed successfully — the empty state
    /// is gated on this, never on `comments.isEmpty` alone.
    var hasLoadedCommentsOnce = false
    var newCommentText = ""
    var isSubmittingComment = false
    var showingError = false
    var errorMessage: String?
    var showingModerationNotice = false
    var moderationNotice: String?
    var hasInvalidApiKey = false
    /// Items (the feedback id governs title + description + rejection reason
    /// together; each comment id its own row) toggled back to original-language
    /// text. Session-scoped: lives exactly as long as this view model, never persisted.
    var showOriginalIDs: Set<UUID> = []

    // Vote dialog state
    var showingVoteDialog = false
    var voteEmail = ""
    var voteNotifyStatusChange = false
    var voteSubscribeToMailingList = SwiftlyFeedback.configuration.mailingListDefaultOptIn
    var voteOperationalEmails = true
    var voteMarketingEmails = true

    /// The explicit client, or `current` once there is one. It does not change after that.
    private var swiftlyFeedback: SwiftlyFeedback?
    /// How long the comment placeholders wait for `configure` before the screen reports it.
    var configurationPatience = SwiftlyFeedback.configurationPatience

    init(feedback: Feedback, swiftlyFeedback: SwiftlyFeedback?) {
        self.currentFeedback = feedback
        self.swiftlyFeedback = swiftlyFeedback
        self.voteNotifyStatusChange = SwiftlyFeedback.configuration.voteNotificationDefaultOptIn
    }

    /// Flips one item (the feedback header as a whole, or one comment) between its
    /// translation and its original text.
    func toggleShowOriginal(_ id: UUID) {
        if showOriginalIDs.contains(id) {
            showOriginalIDs.remove(id)
        } else {
            showOriginalIDs.insert(id)
        }
    }

    /// The client, if there is one yet. The screen can be older than the client.
    private func resolvedClient() -> SwiftlyFeedback? {
        if swiftlyFeedback == nil { swiftlyFeedback = SwiftlyFeedback.current }
        return swiftlyFeedback
    }

    /// The first load, from the view's `.task`. If `configure` has not finished, this waits for
    /// as long as the screen is up, so a late `configure` still fills the comments. After
    /// `configurationPatience` the placeholders stop and the screen reports the failure.
    func loadComments() async {
        guard !hasInvalidApiKey else { return }
        if resolvedClient() == nil {
            isLoadingComments = true
            let patience = configurationPatience
            let deadline = Task {
                try? await Task.sleep(for: patience)
                guard !Task.isCancelled else { return }
                SDKLogger.error("No client after \(patience). Call SwiftlyFeedback.configure, or pass a client to the view.")
                isLoadingComments = false
                errorMessage = String(localized: .errorGeneric)
                showingError = true
            }
            let client = await SwiftlyFeedback.waitForCurrent()
            deadline.cancel()
            isLoadingComments = false
            guard client != nil else { return }
        }
        await refreshComments()
    }

    /// A reload the user asked for. It does not wait: a pull's spinner must end.
    func refreshComments() async {
        guard let sf = resolvedClient() else { return }
        guard !hasInvalidApiKey else { return }

        isLoadingComments = true
        defer { isLoadingComments = false }

        do {
            comments = try await sf.getComments(for: currentFeedback.id)
            hasLoadedCommentsOnce = true
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: .errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    func toggleVote() async {
        guard resolvedClient() != nil else { return }
        guard !hasInvalidApiKey else { return }

        let config = SwiftlyFeedback.configuration

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
                await submitVote(email: configuredEmail, notify: config.voteNotificationDefaultOptIn, subscribeToMailingList: config.mailingListDefaultOptIn, mailingListEmailTypes: buildVoteEmailTypes())
            } else if config.showVoteEmailField {
                // No configured email - show dialog to collect email
                voteEmail = ""
                voteNotifyStatusChange = config.voteNotificationDefaultOptIn
                voteSubscribeToMailingList = config.mailingListDefaultOptIn
                showingVoteDialog = true
            } else {
                // No email configured and dialog disabled - vote without email
                await submitVote(email: nil, notify: false)
            }
        }
    }

    func buildVoteEmailTypes() -> [String]? {
        guard voteSubscribeToMailingList else { return nil }
        var types: [String] = []
        if voteOperationalEmails { types.append("operational") }
        if voteMarketingEmails { types.append("marketing") }
        return types.isEmpty ? nil : types
    }

    func submitVote(email: String?, notify: Bool, subscribeToMailingList: Bool? = nil, mailingListEmailTypes: [String]? = nil) async {
        guard let sf = resolvedClient() else { return }
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
                    notifyStatusChange: notify && validEmail != nil,
                    subscribeToMailingList: validEmail != nil ? subscribeToMailingList : nil,
                    mailingListEmailTypes: validEmail != nil && subscribeToMailingList == true ? mailingListEmailTypes : nil
                )
            }

            currentFeedback = currentFeedback.applying(result)
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: .errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    func reportCurrent(reason: ContentReportReason) async {
        guard let sf = resolvedClient() else {
            present(SwiftlyFeedbackError.invalidResponse)
            return
        }
        do {
            _ = try await sf.reportFeedback(id: currentFeedback.id, reason: reason)
            moderationNotice = String(localized: .moderationReportThanks)
            showingModerationNotice = true
        } catch {
            present(error)
        }
    }

    /// Returns whether the block was stored. The detail screen dismisses only then.
    func blockAuthor() async -> Bool {
        guard let sf = resolvedClient() else {
            present(SwiftlyFeedbackError.invalidResponse)
            return false
        }
        do {
            _ = try await sf.blockUser(id: currentFeedback.userId)
            return true
        } catch {
            present(error)
            return false
        }
    }

    func report(_ comment: Comment, reason: ContentReportReason) async {
        guard let sf = resolvedClient() else {
            present(SwiftlyFeedbackError.invalidResponse)
            return
        }
        do {
            _ = try await sf.reportComment(id: comment.id, on: currentFeedback.id, reason: reason)
            moderationNotice = String(localized: .moderationReportThanks)
            showingModerationNotice = true
        } catch {
            present(error)
        }
    }

    /// Returns whether the block was stored. The caller reloads the list only then.
    func block(commenterUserId: String) async -> Bool {
        guard let sf = resolvedClient() else {
            present(SwiftlyFeedbackError.invalidResponse)
            return false
        }
        do {
            _ = try await sf.blockUser(id: commenterUserId)
            comments.removeAll { $0.userId == commenterUserId }
            moderationNotice = String(localized: .moderationBlockThanks)
            showingModerationNotice = true
            return true
        } catch {
            present(error)
            return false
        }
    }

    private func present(_ error: any Error) {
        errorMessage = error.localizedDescription
        showingError = true
    }

    func submitComment() async {
        guard let sf = resolvedClient(), !newCommentText.isEmpty else {
            isSubmittingComment = false
            return
        }
        guard !hasInvalidApiKey else {
            isSubmittingComment = false
            return
        }

        isSubmittingComment = true
        defer { isSubmittingComment = false }

        do {
            let comment = try await sf.addComment(to: currentFeedback.id, content: newCommentText)
            comments.append(comment)
            newCommentText = ""
        } catch let error as SwiftlyFeedbackError where error == .invalidApiKey {
            hasInvalidApiKey = true
        } catch SwiftlyFeedbackError.feedbackLimitReached(let message) {
            errorMessage = message ?? String(localized: .errorFeedbackLimitMessage)
            showingError = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}
