#if os(macOS)
import SwiftUI

/// macOS comments: an iMessage-style group chat in the detail's inspector, the same
/// bubbles the Admin app uses. Staff on the trailing side, everyone else leading with
/// a two-letter avatar in a stable colour per person.
struct FeedbackDetailChatView: View {
    @Bindable var viewModel: FeedbackDetailViewModel
    let translator: FeedbackTranslator
    let target: Locale.Language
    var onCommenterBlocked: () -> Void = {}

    @SwiftUI.Environment(\.locale) private var locale
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var tint: Color {
        SwiftlyFeedback.appearance.primaryColor.resolve(for: colorScheme)
    }

    /// Oldest first, the way a chat reads.
    private var ordered: [Comment] {
        viewModel.comments.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    }

    private var trimmedText: String {
        viewModel.newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool { !trimmedText.isEmpty && !viewModel.isSubmittingComment }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(String(localized: .commentsCount(viewModel.comments.count)))
                    .font(.headline)
                    .monospacedDigit()
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .accessibilityAddTraits(.isHeader)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                            ForEach(0..<3, id: \.self) { index in
                                ChatBubbleRow(
                                    text: "Placeholder comment body that wraps onto a second line.",
                                    senderName: "Placeholder",
                                    avatarName: "placeholder",
                                    isOutgoing: index == 1
                                )
                            }
                            .redacted(reason: .placeholder)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(String(localized: .accessibilityLoadingComments))
                        } else if viewModel.comments.isEmpty && viewModel.hasLoadedCommentsOnce {
                            CommentsEmptyStateView()
                                .frame(maxWidth: .infinity, minHeight: 220)
                        } else {
                            bubbles
                        }
                    }
                    .padding(12)
                }
                .defaultScrollAnchor(.bottom)
                .onChange(of: viewModel.comments.count) {
                    if let last = ordered.last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            Divider()
            composer
        }
    }

    private var bubbles: some View {
        let ordered = ordered
        let currentUserId = UserIdentifier.getCurrentUserId()
        return ForEach(Array(ordered.enumerated()), id: \.element.id) { index, comment in
            let previous = index > 0 ? ordered[index - 1] : nil
            let next = index + 1 < ordered.count ? ordered[index + 1] : nil
            let startsGroup = previous.map { !Self.sameSender($0, comment) } ?? true
            let endsGroup = next.map { !Self.sameSender($0, comment) } ?? true
            let projection = translationProjection(for: comment)
            let isShowingOriginal = viewModel.showOriginalIDs.contains(comment.id)
            let text = (!isShowingOriginal ? projection.text : nil) ?? comment.content
            let role = CommentAuthorRole.resolve(
                commentUserId: comment.userId, isAdmin: comment.isAdmin, currentUserId: currentUserId
            )
            let bubble = ChatBubbleRow(
                text: text,
                senderName: Self.name(for: role),
                avatarName: comment.userId,
                isOutgoing: comment.isAdmin,
                startsGroup: startsGroup,
                endsGroup: endsGroup,
                timeText: comment.createdAt?.formatted(date: .abbreviated, time: .shortened),
                outgoingTint: tint,
                // Staff replies are not the reader's own: name them, as users are named.
                showsOutgoingSenderName: true
            ) {
                if let sourceName = projection.sourceName {
                    TranslationAffordanceView(
                        sourceLanguageName: sourceName,
                        targetLanguageName: projection.targetName,
                        isShowingOriginal: isShowingOriginal,
                        onToggle: { viewModel.toggleShowOriginal(comment.id) }
                    )
                }
            }
            bubble
                .contextMenu {
                    Button(String(localized: .commentCopy), systemImage: "doc.on.doc") {
                        Self.copyToPasteboard(text)
                    }
                    if ModerationMenuVisibility.isVisible(authorUserId: comment.userId, currentUserId: currentUserId) {
                        ContentModerationMenuItems(
                            onReport: { reason in Task { await viewModel.report(comment, reason: reason) } },
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
                // One element per comment: sender, text, time, with the translation toggle
                // folded in as an action. Copy is an action too, as in the context menu.
                .accessibilityElement(children: .combine)
                .accessibilityAction(named: String(localized: .commentCopy)) { Self.copyToPasteboard(text) }
                .accessibilityIdentifier("fbk-comment-bubble-\(comment.id.uuidString)")
                .padding(.top, startsGroup && index > 0 ? 10 : 0)
                .id(comment.id)
        }
    }

    /// iMessage-style composer: a capsule field and a send arrow in the accent colour.
    private var composer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(String(localized: .feedbackDetailCommentsAdd), text: $viewModel.newCommentText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.background, in: .capsule)
                .overlay(Capsule().strokeBorder(.separator))
                .onSubmit(submit)
                .onKeyPress(.return) {
                    guard canSubmit else { return .ignored }
                    submit()
                    return .handled
                }

            Button(action: submit) {
                if viewModel.isSubmittingComment {
                    ProgressView().controlSize(.small)
                } else {
                    Label(String(localized: .accessibilityPostComment), systemImage: "arrow.up.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .foregroundStyle(canSubmit ? tint : Color.secondary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!canSubmit)
            .help(String(localized: .accessibilityPostComment))
            .accessibilityLabel(String(localized: .accessibilityPostComment))
        }
        .padding(10)
    }

    private func submit() {
        guard canSubmit else { return }
        viewModel.isSubmittingComment = true
        Task { await viewModel.submitComment() }
    }

    /// Copies the text a bubble shows, translated or original.
    private static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func sameSender(_ lhs: Comment, _ rhs: Comment) -> Bool {
        lhs.isAdmin == rhs.isAdmin && lhs.userId == rhs.userId
    }

    private static func name(for role: CommentAuthorRole) -> String {
        switch role {
        case .me: String(localized: .commentAuthorMe)
        case .admin: String(localized: .commentAuthorAdmin)
        case .user: String(localized: .commentAuthorUser)
        }
    }

    private func translationProjection(
        for comment: Comment
    ) -> (text: String?, sourceName: String?, targetName: String?) {
        guard let text = translator.translation(
            for: comment.id, field: .commentText, target: target, sourceText: comment.content
        ) else { return (nil, nil, nil) }
        guard let sourceName = SourceLanguageDetector.detect(comment.content)?
            .localizedDisplayName(in: locale) else { return (nil, nil, nil) }
        let targetName: String? = target.isSameLanguage(as: locale.language)
            ? nil
            : target.localizedTargetName(in: locale)
        return (text, sourceName, targetName)
    }
}
#endif
