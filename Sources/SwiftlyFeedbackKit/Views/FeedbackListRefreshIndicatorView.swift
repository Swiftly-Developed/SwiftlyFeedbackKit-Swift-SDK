import SwiftUI

/// Shown over the populated list while a programmatic refresh is in flight
/// (post-submit, post-vote, macOS ⌘R). User pulls use the system pull-to-refresh
/// spinner instead, so the two never double up.
struct FeedbackListRefreshIndicatorView: View {
    var body: some View {
        // ProgressView justified (UI01 S1): indeterminate *action* — refresh in
        // flight over rows that remain on screen; not a content load.
        ProgressView()
            .controlSize(.small)
            .accessibilityLabel(String(localized: .accessibilityRefreshingFeedback))
    }
}

#Preview {
    FeedbackListRefreshIndicatorView()
}
