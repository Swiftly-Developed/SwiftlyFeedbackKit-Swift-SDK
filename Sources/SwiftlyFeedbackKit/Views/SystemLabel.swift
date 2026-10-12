import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Body text drawn with the system label color on the system background.
///
/// A SwiftUI `Text` that also sets `.font` and `.foregroundStyle(.primary)` reports a
/// font the Dynamic Type audit treats as only partly supported, and a section header
/// stays in the secondary color, which misses 4.5:1. A label control uses
/// `preferredFont(forTextStyle:)` and `label` on `systemBackground`, which passes
/// in both appearances.
struct SystemLabel: View {
    let text: String
    #if canImport(UIKit)
    var textStyle: UIFont.TextStyle = .body
    #elseif canImport(AppKit)
    var textStyle: NSFont.TextStyle = .body
    #endif
    /// System-background title on a label-colored fill, for a button that stays
    /// 4.5:1 in light and dark. A prominent tint of `.primary` is white on white
    /// in dark mode.
    var inverted: Bool = false

    var body: some View {
        SystemLabelBox(text: text, textStyle: textStyle, inverted: inverted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain)
    }
}

#if canImport(UIKit)
private struct SystemLabelBox: UIViewRepresentable {
    let text: String
    var textStyle: UIFont.TextStyle = .body
    var inverted: Bool = false

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.isAccessibilityElement = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        configure(label)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        configure(label)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIView.layoutFittingExpandedSize.width
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: UIView.layoutFittingExpandedSize.height))
        return CGSize(width: min(fitted.width, width), height: fitted.height)
    }

    private func configure(_ label: UILabel) {
        label.font = UIFont.preferredFont(forTextStyle: textStyle)
        label.textColor = inverted ? .systemBackground : .label
        label.backgroundColor = inverted ? .label : .systemBackground
        label.text = text
        label.accessibilityLabel = text
    }
}
#elseif canImport(AppKit)
private struct SystemLabelBox: NSViewRepresentable {
    let text: String
    var textStyle: NSFont.TextStyle = .body
    var inverted: Bool = false

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.drawsBackground = true
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.setContentHuggingPriority(.required, for: .horizontal)
        configure(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        configure(field)
    }

    private func configure(_ field: NSTextField) {
        field.font = NSFont.preferredFont(forTextStyle: textStyle)
        field.textColor = inverted ? .windowBackgroundColor : .labelColor
        field.backgroundColor = inverted ? .labelColor : .windowBackgroundColor
        field.stringValue = text
        field.setAccessibilityLabel(text)
    }
}
#endif
