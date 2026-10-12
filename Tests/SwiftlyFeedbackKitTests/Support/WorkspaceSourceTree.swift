import Foundation

/// Locating and reading the workspace's sources from inside the SDK package's test target.
///
/// `QA-UNIT05-FEEDBACK` has two claims no in-process value can carry:
///
/// - **`-07` / F4** — that the SDK's `FeedbackStatus` declares *no glyph channel at all*. An
///   absent member cannot be called, so the only way to record the gap is to read the
///   declaration. `§4.4`'s corollary is explicit that a missing channel is **this** suite's
///   red rather than `QA-UI03-FEEDBACK`'s, because a view cannot render a value that does not
///   exist and the gap would otherwise vanish from both matrices.
/// - **`-11`** — that the four shipped can-vote predicates partition their six cases
///   identically. Three of the four are in Kotlin, Dart and another Swift *package*; none is
///   linkable from here, and each lane's own runner can only ever see its own.
///
/// Every path is resolved from `#filePath`, so this works in any checkout or worktree.
/// Convention follows `SwiftlyFeedbackAdminTests/Support/AdminSourceTree.swift` and
/// `SwiftlyFeedbackServer/Tests/AppTests/ProjectTierGatingDriftTests.swift`.
enum WorkspaceSourceTree {

    /// Walk up from `Tests/SwiftlyFeedbackKitTests/Support/` to the SDK package root.
    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Support
            .deletingLastPathComponent()  // SwiftlyFeedbackKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // SwiftlyFeedbackKit
    }

    /// The directory holding every subproject.
    static var workspaceRoot: URL { packageRoot.deletingLastPathComponent() }

    enum SourceError: Error, CustomStringConvertible {
        case notInWorkspace(String)
        case unreadable(String)

        var description: String {
            switch self {
            case let .notInWorkspace(path):
                return """
                \(path) is not the FeedbackKit workspace root — the sibling subproject \
                checkouts are missing. The cross-client gates are workspace-only and are \
                meaningless in the published SDK-only mirror.
                """
            case let .unreadable(path):
                return "Could not read \(path). A cross-client gate cannot be green over a file it never opened."
            }
        }
    }

    /// Confirms this really is the workspace before any cross-subproject gate runs, so a
    /// moved package fails loudly instead of silently gating nothing.
    static func requireWorkspace() throws {
        let markers = [
            "SwiftlyFeedbackKit",
            "SwiftlyFeedbackKit-Vapor",
            "SwiftlyFeedbackKit-Kotlin",
            "SwiftlyFeedbackKit-Flutter",
            "SwiftlyFeedbackKit-RN",
        ]
        for marker in markers {
            let path = workspaceRoot.appendingPathComponent(marker).path
            guard FileManager.default.fileExists(atPath: path) else {
                throw SourceError.notInWorkspace(workspaceRoot.path)
            }
        }
    }

    /// The text of a workspace-relative source file.
    static func source(_ relativePath: String) throws -> String {
        let url = workspaceRoot.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw SourceError.unreadable(url.path)
        }
        return text
    }

    /// The text of a file in the SDK package itself.
    static func sdkSource(_ relativePath: String) throws -> String {
        let url = packageRoot.appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw SourceError.unreadable(url.path)
        }
        return text
    }

    /// The slice of `text` from the first line containing `start` up to, but not including,
    /// the first subsequent line containing `end`.
    ///
    /// Used to isolate **one** declaration before scanning it, so a token found three
    /// declarations away cannot satisfy an assertion about this one. Returns `nil` when
    /// either anchor is missing, which every caller treats as a failure rather than a skip.
    static func slice(_ text: String, from start: String, to end: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        guard let first = lines.firstIndex(where: { $0.contains(start) }) else { return nil }
        let rest = lines[(first + 1)...]
        guard let last = rest.firstIndex(where: { $0.contains(end) }) else { return nil }
        return lines[first..<last].joined(separator: "\n")
    }
}
