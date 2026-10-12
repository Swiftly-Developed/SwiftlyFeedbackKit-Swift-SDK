import SwiftUI

/// The package's single motion-policy component (UI-DESIGN-IOS.md → Motion).
///
/// Holds the SDK's **only** `accessibilityReduceMotion` environment read and
/// resolves every requested animation or transition against it: the reduced
/// equivalent — a cross-fade, or none — is chosen here, by the policy, never
/// by the call site. No `.animation` / `.transition` / `withAnimation` site
/// may read the preference itself or bypass this type.
struct MotionPolicy: DynamicProperty {
    @SwiftUI.Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Returns the requested animation, or `nil` (no animation) under Reduce Motion.
    func animation(_ requested: Animation) -> Animation? {
        reduceMotion ? nil : requested
    }

    /// Returns the requested transition, or a plain cross-fade under Reduce Motion.
    func transition(_ requested: AnyTransition) -> AnyTransition {
        reduceMotion ? .opacity : requested
    }
}
