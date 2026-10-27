import SwiftUI

/// One iMessage-style chat bubble, shared by the SDK's comment chat and the Admin app.
///
/// Outgoing (staff) messages sit on the trailing side in an accent-tinted bubble; everyone
/// else sits on the leading side in a gray bubble with an ``InitialsAvatar``. Runs of
/// messages from one sender show the name on the first bubble and avatar and time on the
/// last, like a group chat. Outgoing runs are unnamed unless ``showsOutgoingSenderName`` is
/// set: in the Admin app they are the reader's own side, in the SDK they are staff.
public struct ChatBubbleRow<Accessory: View>: View {
    public let text: String
    public let senderName: String
    /// Initials and colour come from this (an id or email keeps one colour per person).
    public let avatarName: String
    public let isOutgoing: Bool
    public var startsGroup: Bool
    public var endsGroup: Bool
    public var timeText: String?
    /// Bubble tint for outgoing messages; the accent colour by default.
    public var outgoingTint: Color
    /// Names outgoing runs too. The SDK sets it, so an end user reads "Admin" above staff replies.
    public var showsOutgoingSenderName: Bool
    private let accessory: Accessory

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    public static var avatarSize: CGFloat { 28 }

    public init(
        text: String,
        senderName: String,
        avatarName: String,
        isOutgoing: Bool,
        startsGroup: Bool = true,
        endsGroup: Bool = true,
        timeText: String? = nil,
        outgoingTint: Color = .accentColor,
        showsOutgoingSenderName: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.text = text
        self.senderName = senderName
        self.avatarName = avatarName
        self.isOutgoing = isOutgoing
        self.startsGroup = startsGroup
        self.endsGroup = endsGroup
        self.timeText = timeText
        self.outgoingTint = outgoingTint
        self.showsOutgoingSenderName = showsOutgoingSenderName
        self.accessory = accessory()
    }

    /// The first bubble of a run carries the sender's name; an outgoing run only when asked.
    static func showsSenderName(isOutgoing: Bool, startsGroup: Bool, showsOutgoingSenderName: Bool) -> Bool {
        startsGroup && (!isOutgoing || showsOutgoingSenderName)
    }

    /// Opaque fills: translucent fills sampled as low contrast in the accessibility audit.
    /// The staff bubble is the tint mixed toward the background, both under primary text
    /// (white on the orange accent is about 2:1).
    private var bubbleFill: Color {
        let dark = colorScheme == .dark
        let base = Color(white: dark ? 0.11 : 1.0)
        if isOutgoing {
            return outgoingTint.mix(with: base, by: dark ? 0.62 : 0.72)
        }
        return Color(white: dark ? 0.24 : 0.90)
    }

    /// "sender, text, time": what assistive tech reads for the bubble, in the order a
    /// sighted reader takes it in. Hosts make the bubble one element with this label.
    public var accessibilityText: String {
        [senderName, text, timeText].compactMap { $0 }.joined(separator: ", ")
    }

    /// The sender split where it may break: the whole name, or an email address broken
    /// after its last `@`, so it never wraps with a hyphen inside its domain
    /// ("north- / wind.app").
    static func senderNameLines(_ name: String) -> [String] {
        guard let at = name.lastIndex(of: "@"),
              at != name.startIndex,
              name.index(after: at) != name.endIndex else { return [name] }
        let split = name.index(after: at)
        return [String(name[..<split]), String(name[split...])]
    }

    /// The sender as drawn: ``senderNameLines(_:)`` joined by a zero-width space, the one
    /// break opportunity in an address. Without it an address is a single word to the line
    /// breaker, which hyphenates it wherever it runs out of room.
    static func senderNameDisplay(_ name: String) -> String {
        senderNameLines(name).joined(separator: "\u{200B}")
    }

    /// One line when it fits, otherwise broken after the `@`. It wraps rather than truncates,
    /// so the sender stays whole at every Dynamic Type size.
    private var senderLine: some View {
        Text(Self.senderNameDisplay(senderName))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(senderName)
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOutgoing {
                Spacer(minLength: 40)
            } else {
                Group {
                    if endsGroup {
                        InitialsAvatar(name: avatarName, size: Self.avatarSize)
                    } else {
                        Color.clear.frame(width: Self.avatarSize, height: Self.avatarSize)
                    }
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
                if Self.showsSenderName(isOutgoing: isOutgoing, startsGroup: startsGroup, showsOutgoingSenderName: showsOutgoingSenderName) {
                    // Sender, text, then time: read in that order where a host combines the
                    // bubble (the SDK). A host that labels the bubble itself with
                    // `accessibilityText` (the Admin app) ignores the children.
                    senderLine
                        .font(.caption)
                        // .secondary sampled under 4.5:1 in the contrast audit.
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    accessory
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bubbleFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if endsGroup, let timeText {
                    Text(timeText)
                        .font(.caption)
                        // .secondary sampled under 4.5:1 in the contrast audit.
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                }
            }
            .frame(maxWidth: 520, alignment: isOutgoing ? .trailing : .leading)

            if !isOutgoing {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }
}

public extension ChatBubbleRow where Accessory == EmptyView {
    init(
        text: String,
        senderName: String,
        avatarName: String,
        isOutgoing: Bool,
        startsGroup: Bool = true,
        endsGroup: Bool = true,
        timeText: String? = nil,
        outgoingTint: Color = .accentColor,
        showsOutgoingSenderName: Bool = false
    ) {
        self.init(
            text: text, senderName: senderName, avatarName: avatarName, isOutgoing: isOutgoing,
            startsGroup: startsGroup, endsGroup: endsGroup, timeText: timeText,
            outgoingTint: outgoingTint, showsOutgoingSenderName: showsOutgoingSenderName
        ) { EmptyView() }
    }
}
