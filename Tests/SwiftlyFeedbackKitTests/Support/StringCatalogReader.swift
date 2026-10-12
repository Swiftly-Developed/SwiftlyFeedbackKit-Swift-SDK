import Foundation

/// Reads the SDK's String Catalog as **data**, so a localization assertion does not depend on
/// the process's ambient locale.
///
/// `QA-UNIT05-FEEDBACK` `-03` claims two different things and only one of them is a runtime
/// claim. That the six localized names are *distinct* and are *not their own lookup keys* is
/// observable through `String(localized:)` in any locale. That a given arm points at the
/// **right** key is not: comparing `localizedDisplayName` to its English twin only holds while
/// the process resolves to `en`, and there is a standing trap in this repo that
/// `String(localized:locale:)` does **not** select the `.lproj` — a per-locale assertion
/// written with it silently reads `en` and passes vacuously.
///
/// So the "right key" half is asserted against the catalog's own `en` value, read from the
/// source file. That is a fact about the shipped resource, true on any machine.
enum StringCatalogReader {

    /// Walk up from `Tests/SwiftlyFeedbackKitTests/Support/` to the package root.
    static var packageRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Support
            .deletingLastPathComponent()  // SwiftlyFeedbackKitTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // SwiftlyFeedbackKit
    }

    static var catalogURL: URL {
        packageRoot.appendingPathComponent(
            "Sources/SwiftlyFeedbackKit/Resources/Localizable.xcstrings"
        )
    }

    enum CatalogError: Error, CustomStringConvertible {
        case unreadable(String)
        case missingKey(String)

        var description: String {
            switch self {
            case let .unreadable(path):
                return "Could not read the SDK String Catalog at \(path)."
            case let .missingKey(key):
                return """
                The SDK String Catalog has no en value for "\(key)". String(localized:) \
                returns the key itself in that case, so every non-empty assertion over this \
                map is green while nothing is localized at all.
                """
            }
        }
    }

    /// The `en` value for `key`, or a throw naming the missing key.
    static func englishValue(for key: String) throws -> String {
        let data = try Data(contentsOf: catalogURL)
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let strings = root["strings"] as? [String: Any]
        else {
            throw CatalogError.unreadable(catalogURL.path)
        }
        guard
            let entry = strings[key] as? [String: Any],
            let localizations = entry["localizations"] as? [String: Any],
            let english = localizations["en"] as? [String: Any],
            let unit = english["stringUnit"] as? [String: Any],
            let value = unit["value"] as? String,
            !value.isEmpty
        else {
            throw CatalogError.missingKey(key)
        }
        return value
    }
}
