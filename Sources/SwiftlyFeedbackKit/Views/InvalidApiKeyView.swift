import SwiftUI

/// Terminal state shown when the server rejected the SDK's API key.
///
/// The Retry button renders only when `onRetry` is provided; the detail and
/// submit call sites pass nothing and compile unchanged (a later phase may
/// wire them).
struct InvalidApiKeyView: View {
    var onRetry: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(Strings.errorInvalidApiKeyTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(Strings.errorInvalidApiKeyMessage)
        } actions: {
            if let onRetry {
                Button(Strings.errorRetryButton) {
                    onRetry()
                }
            }
        }
    }
}

#Preview {
    InvalidApiKeyView(onRetry: {})
}
