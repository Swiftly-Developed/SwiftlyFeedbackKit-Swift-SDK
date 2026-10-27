import SwiftUI

/// The Classic list: the plain list from SwiftlyFeedbackKit 2.0, plus the shared
/// "Filtered by" row.
struct FeedbackListContentView: View {
    @Bindable var viewModel: FeedbackListViewModel
    let translator: FeedbackTranslator
    /// The reader's resolved target, handed down rather than re-derived: this view
    /// enqueues nothing and only reads cached projections, so a seam of its own would
    /// mean a second independently-timed answer and a render disagreeing with its parent.
    let target: Locale.Language
    private var motion = MotionPolicy()

    init(viewModel: FeedbackListViewModel, translator: FeedbackTranslator, target: Locale.Language) {
        self.viewModel = viewModel
        self.translator = translator
        self.target = target
    }

    var body: some View {
        List {
            if viewModel.filter.isActive {
                FeedbackListFilterSummaryRow(filter: viewModel.filter) {
                    viewModel.clearFilters()
                }
                .transition(motion.transition(.opacity))
            }
            ForEach(viewModel.displayedItems) { feedback in
                FeedbackListRow(
                    viewModel: viewModel,
                    feedback: feedback,
                    translator: translator,
                    target: target,
                    style: .classic
                )
                .transition(motion.transition(.opacity.combined(with: .move(edge: .top))))
            }
        }
        .listStyle(.plain)
        .animation(motion.animation(.smooth), value: viewModel.displayedItems)
        .animation(motion.animation(.smooth), value: viewModel.filter)
        .navigationDestination(for: Feedback.self) { feedback in
            FeedbackDetailView(
                feedback: feedback,
                swiftlyFeedback: viewModel.swiftlyFeedback,
                onModerationChange: { event in
                    switch event {
                    case .blockedAuthor:
                        viewModel.noteAuthorBlocked()
                        Task { await viewModel.loadFeedback() }
                    case .blockedCommenter:
                        Task { await viewModel.loadFeedback() }
                    case .reported:
                        break
                    }
                }
            )
        }
    }
}
