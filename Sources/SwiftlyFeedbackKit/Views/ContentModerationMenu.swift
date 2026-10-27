import SwiftUI

/// Report and block actions for one post or comment.
///
/// Reasons are a nested menu so the control works in a list row and in a
/// toolbar. The caller records the request and surfaces the acknowledgement.
struct ContentModerationMenu: View {
    let onReport: (ContentReportReason) -> Void
    let onBlock: () -> Void

    var body: some View {
        Menu {
            ContentModerationMenuItems(onReport: onReport, onBlock: onBlock)
        } label: {
            Label(String(localized: .moderationActions), systemImage: "ellipsis.circle")
        }
        .labelStyle(.iconOnly)
        #if os(macOS)
        // A bare glyph: the bordered pull-down drew a box with its own chevron that sat
        // out of line with the row's other trailing controls.
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        #endif
        .help(String(localized: .moderationActions))
    }
}

/// The report and block items, for a pull-down menu or a context menu.
struct ContentModerationMenuItems: View {
    let onReport: (ContentReportReason) -> Void
    let onBlock: () -> Void

    var body: some View {
            Menu {
                ForEach(ContentReportReason.allCases, id: \.self) { reason in
                    Button(title(for: reason)) {
                        onReport(reason)
                    }
                }
            } label: {
                Label(String(localized: .moderationReport), systemImage: "flag")
            }

            Button(String(localized: .moderationBlockUser), systemImage: "hand.raised", role: .destructive) {
                onBlock()
            }
    }

    private func title(for reason: ContentReportReason) -> String {
        switch reason {
        case .spam:
            String(localized: .moderationReasonSpam)
        case .harassment:
            String(localized: .moderationReasonHarassment)
        case .hate:
            String(localized: .moderationReasonHate)
        case .sexualContent:
            String(localized: .moderationReasonSexualContent)
        case .violence:
            String(localized: .moderationReasonViolence)
        case .other:
            String(localized: .moderationReasonOther)
        }
    }
}
