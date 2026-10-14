import CoreGraphics

/// Shared Showcase layout values. Base sizes for `@ScaledMetric`, except the hit target,
/// which is a floor and never scales down.
enum FeedbackShowcaseMetrics {
    static let minimumHitSize: CGFloat = 44
    static let capsuleHorizontalPadding: CGFloat = 12
    #if os(iOS)
    static let sectionSpacing: CGFloat = 14
    #endif
}
