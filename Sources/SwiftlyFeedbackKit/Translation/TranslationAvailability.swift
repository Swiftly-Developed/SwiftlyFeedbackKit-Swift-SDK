import Foundation

/// Platform-neutral mirror of the Translation framework's `LanguageAvailability.Status`.
///
/// Defined outside any platform guard so `#else`-arm call sites (visionOS, where the
/// Translation framework is a stub) share the same vocabulary as the real implementation.
/// Availability states render nothing themselves — rendering is the view layer's concern.
enum TranslationAvailability: Sendable, Equatable {
    /// The language pair cannot be translated on this device (or translation is disabled).
    case unsupported
    /// The pair is supported but the language models are not yet downloaded.
    case needsDownload
    /// The pair's language models are installed and ready.
    case installed
}
