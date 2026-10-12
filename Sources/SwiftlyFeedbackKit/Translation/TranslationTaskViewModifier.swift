import SwiftUI

// The compound guard is deliberate: the visionOS SDK ships a STUB Translation.framework
// whose every symbol is unavailable, so a bare `#if canImport(Translation)` evaluates
// TRUE on visionOS and compiles the wrong arm. Both arms declare the identical surface,
// so the two call sites (list and detail roots) stay fork-free.
#if canImport(Translation) && (os(iOS) || os(macOS))
import Translation

extension View {
    /// The single guarded wiring seam between the SDK's views and the Translation
    /// framework: applies the framework's translation task driven by `translator`'s
    /// published configuration. The `session` is a closure parameter for the duration
    /// of one batch and is never stored — phase 06's session-not-retained contract.
    func feedbackTranslationTask(_ translator: FeedbackTranslator) -> some View {
        translationTask(translator.configuration) { session in
            await translator.run(session: session)
        }
    }
}

#else

extension View {
    /// Platform fallback: no usable Translation framework, so the view is returned
    /// unchanged. The translator's cache never fills and no affordance ever mounts.
    func feedbackTranslationTask(_ translator: FeedbackTranslator) -> some View {
        self
    }
}

#endif
