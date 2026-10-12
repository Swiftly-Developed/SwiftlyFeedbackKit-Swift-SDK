import SwiftUI

/// Small capsule indicator shown over the populated list while a programmatic
/// refresh is in flight (post-submit, post-vote, macOS ⌘R). User pulls use the
/// system pull-to-refresh spinner instead, so the two never double up.
struct FeedbackListRefreshIndicatorView: View {
    var body: some View {
        // ProgressView justified (UI01 S1): indeterminate *action* — refresh in
        // flight over rows that remain on screen; not a content load.
        ProgressView()
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .accessibilityLabel(Strings.accessibilityRefreshingFeedback)
    }
}

#Preview {
    FeedbackListRefreshIndicatorView()
        .padding()
}
