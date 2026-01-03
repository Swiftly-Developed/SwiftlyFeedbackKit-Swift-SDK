import SwiftUI

/// Theme configuration for SwiftlyFeedback SDK.
///
/// Access via `SwiftlyFeedback.theme`.
///
/// Example:
/// ```swift
/// SwiftlyFeedback.theme.primaryColor = .blue
/// SwiftlyFeedback.theme.secondaryColor = .set(light: .gray, dark: .white)
/// ```
public final class SwiftlyFeedbackTheme: @unchecked Sendable {

    // MARK: - Colors

    /// Primary color used for buttons and accents. Default: `.accentColor`
    public var primaryColor: ThemeColor = .default

    /// Secondary color used for secondary elements. Default: `.secondary`
    public var secondaryColor: ThemeColor = .default

    /// Tertiary color used for backgrounds. Default: `.tertiary`
    public var tertiaryColor: ThemeColor = .default

    /// Badge colors for different statuses
    public var statusColors = StatusColors()

    /// Badge colors for different categories
    public var categoryColors = CategoryColors()

    internal init() {}
}

// MARK: - Theme Color

/// A color that can be different for light and dark mode.
public enum ThemeColor: Sendable {
    case `default`
    case color(Color)
    case adaptive(light: Color, dark: Color)

    /// Creates a color with different values for light and dark mode.
    public static func set(light: Color, dark: Color) -> ThemeColor {
        .adaptive(light: light, dark: dark)
    }

    /// Resolves the color for the current color scheme.
    @MainActor
    public func resolve(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .default:
            return .accentColor
        case .color(let color):
            return color
        case .adaptive(let light, let dark):
            return colorScheme == .dark ? dark : light
        }
    }
}

// MARK: - Status Colors

public final class StatusColors: @unchecked Sendable {
    public var pending: Color = .gray
    public var approved: Color = .blue
    public var inProgress: Color = .orange
    public var completed: Color = .green
    public var rejected: Color = .red

    internal init() {}

    public func color(for status: FeedbackStatus) -> Color {
        switch status {
        case .pending: return pending
        case .approved: return approved
        case .inProgress: return inProgress
        case .completed: return completed
        case .rejected: return rejected
        }
    }
}

// MARK: - Category Colors

public final class CategoryColors: @unchecked Sendable {
    public var featureRequest: Color = .purple
    public var bugReport: Color = .red
    public var improvement: Color = .teal
    public var other: Color = .gray

    internal init() {}

    public func color(for category: FeedbackCategory) -> Color {
        switch category {
        case .featureRequest: return featureRequest
        case .bugReport: return bugReport
        case .improvement: return improvement
        case .other: return other
        }
    }
}
