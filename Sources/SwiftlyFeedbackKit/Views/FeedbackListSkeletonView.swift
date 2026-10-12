import SwiftUI

/// The feedback list's content-load skeleton: six ghost rows in the same
/// container shape (`ScrollView` + `LazyVStack`, spacing 12, padded) as the
/// loaded content, so the swap to real data shifts no layout.
///
/// The region reads as a single VoiceOver element naming what is loading —
/// a skeleton that is silent to VoiceOver is a blank screen.
struct FeedbackListSkeletonView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    FeedbackCardSkeletonView()
                }
            }
            .padding()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Strings.accessibilityLoadingFeedback)
    }
}

#Preview {
    FeedbackListSkeletonView()
}
