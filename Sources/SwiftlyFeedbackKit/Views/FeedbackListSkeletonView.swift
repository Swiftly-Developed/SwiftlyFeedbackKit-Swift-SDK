import SwiftUI

/// The feedback list's content-load skeleton: six ghost rows in a plain `List`,
/// matching the loaded list so the swap to real data shifts no layout.
///
/// The region reads as a single VoiceOver element naming what is loading —
/// a skeleton that is silent to VoiceOver is a blank screen.
struct FeedbackListSkeletonView: View {
    var body: some View {
        List {
            ForEach(0..<6, id: \.self) { _ in
                FeedbackCardSkeletonView()
            }
        }
        .listStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: .accessibilityLoadingFeedback))
    }
}

#Preview {
    FeedbackListSkeletonView()
}
