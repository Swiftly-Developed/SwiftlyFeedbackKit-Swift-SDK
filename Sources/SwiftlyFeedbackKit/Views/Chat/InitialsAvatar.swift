import SwiftUI

/// A circle with two-letter initials on a stable system colour. Shared by the SDK's
/// comment chat and the FeedbackKit Admin app, so one person looks the same everywhere.
public struct InitialsAvatar: View {
    /// Display name, email or SDK user id. The initials come from this.
    public let name: String
    /// What the colour is derived from; defaults to `name`. Pass an id or email so
    /// the same person keeps one colour.
    public var colorKey: String?
    public var size: CGFloat
    /// Grows the circle and initials with the user's Dynamic Type setting.
    @ScaledMetric(relativeTo: .caption) private var scale: CGFloat = 1

    public init(name: String, colorKey: String? = nil, size: CGFloat = 28) {
        self.name = name
        self.colorKey = colorKey
        self.size = size
    }

    /// Distinct system hues, one per person. Yellow, mint and cyan are left out. The
    /// fill is each hue mixed 45% towards black (`fill(for:)`), so white initials stay
    /// above 4.5:1 in light and dark mode.
    public static let palette: [Color] = [.blue, .green, .orange, .pink, .purple, .teal, .indigo, .red, .brown]

    /// Platform prefixes SDK user ids carry ("web_amara.okafor"). They are not part
    /// of the person's name, so they never become an initial.
    static let idPrefixes: Set<String> = [
        "ios", "ipados", "macos", "mac", "web", "android", "tvos", "watchos",
        "visionos", "flutter", "rn", "kotlin", "js", "sdk", "user", "anon", "anonymous"
    ]

    public static func initials(for name: String) -> String {
        var source = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let at = source.firstIndex(of: "@") { source = String(source[..<at]) }
        if let underscore = source.firstIndex(of: "_") {
            let prefix = source[..<underscore].lowercased()
            let rest = source[source.index(after: underscore)...]
            if idPrefixes.contains(prefix), rest.contains(where: { $0.isLetter }) {
                source = String(rest)
            }
        }
        // Email local parts and SDK ids split on separators ("maya.chen" -> "MC").
        let words = source
            .replacingOccurrences(of: "[._\\-+]", with: " ", options: .regularExpression)
        let result = project(from: words)
        return result.isEmpty ? "?" : result
    }

    /// FNV-1a over the UTF-8 bytes: stable across launches, unlike `hashValue`.
    public static func color(for key: String) -> Color {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return palette[Int(hash % UInt64(palette.count))]
    }

    /// A Dynamic Type text style that matches the circle at the default text size.
    static func textStyle(for size: CGFloat) -> Font {
        switch size {
        case ..<26: .caption2
        case ..<34: .caption
        case ..<44: .headline
        case ..<60: .title2
        default: .largeTitle
        }
    }

    /// The circle's fill: the person's hue, darkened so white text passes contrast.
    public static func fill(for key: String) -> Color {
        color(for: key).mix(with: .black, by: 0.45)
    }

    public var body: some View {
        let side = size * scale
        return Text(Self.initials(for: name))
            .font(Self.textStyle(for: size).weight(.semibold))
            .fontDesign(.rounded)
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .frame(width: side, height: side)
            .background(Self.fill(for: colorKey ?? name), in: .circle)
            .accessibilityHidden(true)
    }

    // First significant character of each of the first two words, or the first two
    // significant characters of a single word.
    private static func project(from name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.filter { $0.isLetter || $0.isNumber }.isEmpty }
        func significant(_ word: String) -> [Character] { word.filter { $0.isLetter || $0.isNumber } }
        if words.count >= 2, let a = significant(words[0]).first, let b = significant(words[1]).first {
            return (String(a) + String(b)).uppercased()
        }
        guard let word = words.first else { return "" }
        return String(significant(word).prefix(2)).uppercased()
    }
}
