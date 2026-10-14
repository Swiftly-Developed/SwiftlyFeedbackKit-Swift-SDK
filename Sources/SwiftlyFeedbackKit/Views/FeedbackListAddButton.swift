import SwiftUI

/// The toolbar control that opens the submit sheet.
struct FeedbackListAddButton: View {
    let allowsSubmission: Bool
    let tint: Color
    let onSubmit: () -> Void
    let onDisabled: () -> Void

    var body: some View {
        Button(String(localized: .feedbackSubmitTitle), systemImage: "plus") {
            if allowsSubmission {
                onSubmit()
            } else {
                onDisabled()
            }
        }
        .tint(tint)
    }
}
