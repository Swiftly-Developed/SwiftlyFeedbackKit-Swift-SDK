import SwiftUI

/// The Showcase list: one grouped section per request, so each request is its own card,
/// with the "Filtered by" row above the first card while a filter is active.
struct FeedbackShowcaseList: View {
    @Bindable var viewModel: FeedbackListViewModel
    let translator: FeedbackTranslator
    /// The reader's resolved target, handed down rather than re-derived.
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
                Section {
                    FeedbackListFilterSummaryRow(filter: viewModel.filter) {
                        viewModel.clearFilters()
                    }
                    .listRowBackground(Color.clear)
                    .transition(motion.transition(.opacity))
                }
            }
            ForEach(viewModel.displayedItems) { feedback in
                Section {
                    FeedbackListRow(
                        viewModel: viewModel,
                        feedback: feedback,
                        translator: translator,
                        target: target,
                        style: .showcase
                    )
                }
                .transition(motion.transition(.opacity.combined(with: .move(edge: .top))))
            }
        }
        .modifier(FeedbackShowcaseListStyleModifier())
        .animation(motion.animation(.smooth), value: viewModel.displayedItems)
        .animation(motion.animation(.smooth), value: viewModel.filter)
        .navigationDestination(for: Feedback.self) { feedback in
            FeedbackDetailView(feedback: feedback, swiftlyFeedback: viewModel.swiftlyFeedback)
        }
    }
}
