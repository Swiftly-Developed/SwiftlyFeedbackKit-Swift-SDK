import SwiftUI

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
            ForEach(viewModel.displayedItems) { feedback in
                FeedbackListRow(
                    viewModel: viewModel,
                    feedback: feedback,
                    translator: translator,
                    target: target
                )
                .transition(motion.transition(.opacity.combined(with: .move(edge: .top))))
            }
        }
        .listStyle(.plain)
        .animation(motion.animation(.smooth), value: viewModel.displayedItems)
        .navigationDestination(for: Feedback.self) { feedback in
            FeedbackDetailView(feedback: feedback, swiftlyFeedback: viewModel.swiftlyFeedback)
        }
    }
}
