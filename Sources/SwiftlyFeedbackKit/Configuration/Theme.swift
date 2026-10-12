import SwiftUI

/// Theme configuration for SwiftlyFeedback SDK.
///
/// Access via `SwiftlyFeedback.theme`.
///
/// Example:
/// ```swift
/// SwiftlyFeedback.theme.primaryColor = .color(.blue)
/// SwiftlyFeedback.theme.primaryColor = .set(light: .gray, dark: .white)
/// ```
public final class SwiftlyFeedbackTheme: @unchecked Sendable {

    // MARK: - Colors

    /// Primary color used for buttons and accents. Default: `.accentColor`
    public var primaryColor: ThemeColor = .default

    /// Badge colors for different statuses
    public var statusColors = StatusColors()

    /// Badge colors for different categories
    public var categoryColors = CategoryColors()

    internal init() {}
}

// MARK: - Theme Color

/// A color that can be different for light and dark mode.
public enum ThemeColor: Sendable, Equatable, Hashable {
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
    public var pending: ThemeColor = .color(.gray)
    public var approved: ThemeColor = .color(.blue)
    public var inProgress: ThemeColor = .color(.orange)
    public var testflight: ThemeColor = .color(.cyan)
    public var completed: ThemeColor = .color(.green)
    public var rejected: ThemeColor = .color(.red)

    internal init() {}

    public func color(for status: FeedbackStatus) -> ThemeColor {
        switch status {
        case .pending: return pending
        case .approved: return approved
        case .inProgress: return inProgress
        case .testflight: return testflight
        case .completed: return completed
        case .rejected: return rejected
        }
    }
}

// MARK: - Category Colors

public final class CategoryColors: @unchecked Sendable {
    public var featureRequest: ThemeColor = .color(.purple)
    public var bugReport: ThemeColor = .color(.red)
    public var improvement: ThemeColor = .color(.teal)
    public var other: ThemeColor = .color(.gray)

    internal init() {}

    public func color(for category: FeedbackCategory) -> ThemeColor {
        switch category {
        case .featureRequest: return featureRequest
        case .bugReport: return bugReport
        case .improvement: return improvement
        case .other: return other
        }
    }
}
