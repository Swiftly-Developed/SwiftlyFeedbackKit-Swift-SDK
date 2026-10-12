import Foundation
import Testing

/// Swift Testing's `Comment` is `ExpressibleByStringInterpolation`, so a literal converts, but a
/// concatenated or multi-line message is a `String` and does not. Fully qualified because the
/// SDK exports its own `Comment` model. File-private: another test file already owns this name.
private func note(_ message: String) -> Testing.Comment { Testing.Comment(rawValue: message) }

/// Gates on `Sources/SwiftlyFeedbackKit/Resources/PrivacyInfo.xcprivacy`.
///
/// A manifest is a claim about code. Nothing compiles it against that code, so the
/// next thing to notice a drift is App Review. Every assertion here is anchored to a
/// scan of `Sources/`, and declared sets are compared for equality: a containment
/// check stays green on an over-declaration, which is its own App Review problem.
///
/// Scope is this package only. The host app and any other SDK ship their own manifests.
@Suite("SDK privacy manifest")
struct PrivacyManifestTests {

    private static let manifestRelativePath = "Sources/SwiftlyFeedbackKit/Resources/PrivacyInfo.xcprivacy"

    private static var sourcesDirectory: URL {
        WorkspaceSourceTree.packageRoot.appendingPathComponent("Sources/SwiftlyFeedbackKit")
    }

    private static var manifestURL: URL {
        WorkspaceSourceTree.packageRoot.appendingPathComponent(manifestRelativePath)
    }

    private func manifest() throws -> [String: Any] {
        let data = try #require(
            try? Data(contentsOf: Self.manifestURL),
            note("Could not read \(Self.manifestURL.path) — the SDK privacy manifest is missing.")
        )
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(parsed as? [String: Any], "PrivacyInfo.xcprivacy is not a plist dictionary")
    }

    /// Shipping Swift sources, comments stripped, concatenated. This file is under Tests/
    /// and is not part of the walk, so the probe tokens spelled below cannot satisfy themselves.
    private func sdkSourceText() throws -> String {
        let files = Self.swiftFiles(under: Self.sourcesDirectory)
        #expect(files.count > 40, note("""
            Only \(files.count) Swift files found under \(Self.sourcesDirectory.path) — the scan is \
            not seeing the SDK, so every "API not used" assertion in this suite is vacuous.
            """))
        return files.map { Self.sourceWithoutComments(at: $0) }.joined(separator: "\n")
    }

    @Test("The manifest declares all four top-level keys")
    func topLevelKeys() throws {
        let dict = try manifest()
        #expect(dict["NSPrivacyTracking"] as? Bool == false)
        #expect((dict["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true,
                "NSPrivacyTrackingDomains must stay empty while NSPrivacyTracking is false")
        #expect(dict["NSPrivacyAccessedAPITypes"] is [Any])
        #expect(dict["NSPrivacyCollectedDataTypes"] is [Any])
    }

    @Test("Package.swift processes Resources, which is where the manifest lives")
    func manifestIsProcessedBySwiftPM() throws {
        #expect(FileManager.default.fileExists(atPath: Self.manifestURL.path))
        let package = try String(
            contentsOf: WorkspaceSourceTree.packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        #expect(package.contains(".process(\"Resources\")"), """
            The SDK target no longer processes Resources. PrivacyInfo.xcprivacy is only bundled \
            when that directory is a processed or copied resource.
            """)
        let resources = Self.sourcesDirectory.appendingPathComponent("Resources")
        #expect(Self.manifestURL.path.hasPrefix(resources.path),
                "The manifest moved out of the processed Resources directory")
    }

    private static let requiredReasonProbes: [(category: String, tokens: [String])] = [
        ("NSPrivacyAccessedAPICategoryUserDefaults", ["UserDefaults"]),
        ("NSPrivacyAccessedAPICategoryFileTimestamp",
         ["creationDate", "contentModificationDate", "attributesOfItem", "NSFileCreationDate", "NSFileModificationDate"]),
        ("NSPrivacyAccessedAPICategorySystemBootTime",
         ["systemUptime", "mach_absolute_time", "kern.boottime"]),
        ("NSPrivacyAccessedAPICategoryDiskSpace",
         ["volumeAvailableCapacity", "volumeTotalCapacity", "systemFreeSize", "attributesOfFileSystem", "statfs"]),
        ("NSPrivacyAccessedAPICategoryActiveKeyboards", ["activeInputModes"]),
    ]

    @Test("Declared required-reason categories equal the categories the sources actually use")
    func requiredReasonCategoriesMatchSources() throws {
        let code = try sdkSourceText()
        let dict = try manifest()

        let declared = Set(
            (dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]] ?? [])
                .compactMap { $0["NSPrivacyAccessedAPIType"] as? String }
        )
        let used = Set(
            Self.requiredReasonProbes
                .filter { probe in probe.tokens.contains { code.contains($0) } }
                .map(\.category)
        )

        #expect(declared == used, note("""
            Required-reason drift.
              declared: \(declared.sorted())
              in code:  \(used.sorted())
            """))
        #expect(used.contains("NSPrivacyAccessedAPICategoryUserDefaults"))
    }

    @Test("UserDefaults is CA92.1 because nothing opens an app-group suite")
    func userDefaultsReasonIsAppOnly() throws {
        let dict = try manifest()
        let entries = try #require(dict["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = entries.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        #expect((userDefaults?["NSPrivacyAccessedAPITypeReasons"] as? [String]) == ["CA92.1"])

        let code = try sdkSourceText()
        #expect(!code.contains("UserDefaults(suiteName"),
                "An app-group suite would make CA92.1 the wrong reason code — CA56.1 covers shared defaults")
    }

    @Test("The declared data types are exactly the measured set")
    func collectedDataTypesAreExact() throws {
        let dict = try manifest()
        let declared = Set(
            (dict["NSPrivacyCollectedDataTypes"] as? [[String: Any]] ?? [])
                .compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        )
        let expected: Set<String> = [
            "NSPrivacyCollectedDataTypeUserID",
            "NSPrivacyCollectedDataTypeEmailAddress",
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypeProductInteraction",
            "NSPrivacyCollectedDataTypeOtherUsageData",
            "NSPrivacyCollectedDataTypePurchaseHistory",
        ]
        #expect(declared == expected, note("""
            Collected-data drift.
              declared: \(declared.sorted())
              expected: \(expected.sorted())
            Do not reconcile by editing this list. Re-read what the SDK sends, decide whether the
            manifest or the code is wrong, and change that.
            """))
    }

    @Test("Every collected type is linked, not tracking, and carries the measured purposes")
    func collectedDataPurposesMatch() throws {
        let dict = try manifest()
        let entries = try #require(dict["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let byType = Dictionary(uniqueKeysWithValues: entries.map { entry in
            (entry["NSPrivacyCollectedDataType"] as? String ?? "", entry)
        })

        let expectedPurposes: [String: Set<String>] = [
            "NSPrivacyCollectedDataTypeUserID": [
                "NSPrivacyCollectedDataTypePurposeAppFunctionality",
                "NSPrivacyCollectedDataTypePurposeAnalytics",
            ],
            "NSPrivacyCollectedDataTypeEmailAddress": [
                "NSPrivacyCollectedDataTypePurposeAppFunctionality",
                "NSPrivacyCollectedDataTypePurposeDeveloperAdvertising",
            ],
            "NSPrivacyCollectedDataTypeOtherUserContent": [
                "NSPrivacyCollectedDataTypePurposeAppFunctionality",
            ],
            "NSPrivacyCollectedDataTypeProductInteraction": [
                "NSPrivacyCollectedDataTypePurposeAppFunctionality",
                "NSPrivacyCollectedDataTypePurposeAnalytics",
            ],
            "NSPrivacyCollectedDataTypeOtherUsageData": [
                "NSPrivacyCollectedDataTypePurposeAnalytics",
            ],
            "NSPrivacyCollectedDataTypePurchaseHistory": [
                "NSPrivacyCollectedDataTypePurposeAnalytics",
            ],
        ]

        for (type, purposes) in expectedPurposes {
            let entry = try #require(byType[type], note("\(type) is missing from the manifest"))
            #expect(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool == true, note("\(type) must be linked"))
            #expect(entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false, note("\(type) must not track"))
            let declared = Set(entry["NSPrivacyCollectedDataTypePurposes"] as? [String] ?? [])
            #expect(declared == purposes, note("""
                \(type) purposes drifted.
                  declared: \(declared.sorted())
                  expected: \(purposes.sorted())
                """))
        }
    }

    /// The bodies that carry personal data off device, and the stored properties each one
    /// had when the manifest was written. A new property fails this test, which is the moment
    /// to ask whether it needs a new collected-data entry.
    @Test("Request bodies transmit exactly the fields the manifest accounts for")
    func requestBodyFieldsArePinned() throws {
        let files = Self.swiftFiles(under: Self.sourcesDirectory)
        let sources = files.map { Self.sourceWithoutComments(at: $0) }
        let expected: [String: Set<String>] = [
            "CreateFeedbackRequest": [
                "title", "description", "category", "userId", "userEmail",
                "subscribeToMailingList", "mailingListEmailTypes",
            ],
            "VoteRequest": [
                "userId", "email", "notifyStatusChange",
                "subscribeToMailingList", "mailingListEmailTypes",
            ],
            "CreateCommentRequest": ["content", "userId", "isAdmin"],
            "RegisterUserRequest": ["userId", "mrr"],
            "TrackViewEventRequest": ["eventName", "userId", "properties"],
        ]

        for (name, fields) in expected.sorted(by: { $0.key < $1.key }) {
            let bodies = sources.flatMap { Self.structBodies(named: name, in: $0) }
            #expect(bodies.count == 1, note("Expected exactly one `struct \(name)`, found \(bodies.count)."))
            guard let body = bodies.first else { continue }
            let found = Self.storedProperties(in: body)
            #expect(found == fields, note("""
                \(name) transmits \(found.sorted()), the manifest was written against \(fields.sorted()).
                """))
        }
    }

    @Test("The only request headers are Content-Type, the API key, and the user id")
    func requestHeadersStayLimited() throws {
        let client = try #require(
            Self.swiftFiles(under: Self.sourcesDirectory)
                .first { $0.lastPathComponent == "APIClient.swift" }
        )
        let source = Self.sourceWithoutComments(at: client)
        let headers = Self.headerNames(in: source)
        #expect(headers == ["Content-Type", "X-API-Key", "X-User-Id"], note("""
            APIClient now sets \(headers). A new header may be a device, OS, app-version, or \
            locale field the manifest does not declare.
            """))
    }

    @Test("Nothing in the SDK contradicts NSPrivacyTracking = false")
    func noTrackingSurfaces() throws {
        let code = try sdkSourceText()
        for token in ["ASIdentifierManager", "advertisingIdentifier", "AppTrackingTransparency",
                      "ATTrackingManager", "identifierForVendor"] {
            #expect(!code.contains(token), note("\(token) is present — NSPrivacyTracking = false needs re-examining"))
        }
    }

    // MARK: - Source walk

    private static func swiftFiles(under directory: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.path < $1.path }
    }

    /// Whole-line and trailing `//` comments, plus non-greedy block comments.
    /// A string literal that contains `//` would be damaged; none of the probes read one.
    private static func sourceWithoutComments(at file: URL) -> String {
        guard let raw = try? String(contentsOf: file, encoding: .utf8) else { return "" }
        let withoutBlocks = raw.replacingOccurrences(
            of: "/\\*.*?\\*/",
            with: "",
            options: [.regularExpression]
        )
        return withoutBlocks
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { return "" }
                if let commentStart = line.range(of: "//") {
                    return String(line[line.startIndex..<commentStart.lowerBound])
                }
                return String(line)
            }
            .joined(separator: "\n")
    }

    private static func isIdentifierUnit(_ unit: unichar) -> Bool {
        (unit >= 65 && unit <= 90)
            || (unit >= 97 && unit <= 122)
            || (unit >= 48 && unit <= 57)
            || unit == 95
    }

    private static func structBodies(named name: String, in text: String) -> [String] {
        let source = text as NSString
        let needle = "struct \(name)"
        var bodies: [String] = []
        var cursor = 0

        while cursor < source.length {
            let found = source.range(of: needle, range: NSRange(location: cursor, length: source.length - cursor))
            guard found.location != NSNotFound else { break }
            cursor = found.location + found.length
            if cursor < source.length, isIdentifierUnit(source.character(at: cursor)) { continue }

            let brace = source.range(of: "{", range: NSRange(location: cursor, length: source.length - cursor))
            guard brace.location != NSNotFound else { continue }
            bodies.append(balancedBraceBody(in: source, openBraceOffset: brace.location))
        }
        return bodies
    }

    private static func balancedBraceBody(in source: NSString, openBraceOffset: Int) -> String {
        guard openBraceOffset < source.length,
              source.character(at: openBraceOffset) == UInt16(UInt8(ascii: "{")) else { return "" }

        var depth = 0
        var inString = false
        var escaped = false
        var index = openBraceOffset

        while index < source.length {
            let scalar = source.character(at: index)
            if escaped {
                escaped = false
            } else if scalar == UInt16(UInt8(ascii: "\\")) {
                escaped = true
            } else if scalar == UInt16(UInt8(ascii: "\"")) {
                inString.toggle()
            } else if !inString {
                if scalar == UInt16(UInt8(ascii: "{")) {
                    depth += 1
                } else if scalar == UInt16(UInt8(ascii: "}")) {
                    depth -= 1
                    if depth == 0 {
                        return source.substring(with: NSRange(
                            location: openBraceOffset + 1,
                            length: index - openBraceOffset - 1
                        ))
                    }
                }
            }
            index += 1
        }
        return ""
    }

    private static func storedProperties(in body: String) -> Set<String> {
        var found: Set<String> = []
        for line in body.components(separatedBy: .newlines) {
            var trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("{") { continue }
            for modifier in ["public ", "internal ", "package ", "fileprivate ", "private "]
            where trimmed.hasPrefix(modifier) {
                trimmed = String(trimmed.dropFirst(modifier.count)).trimmingCharacters(in: .whitespaces)
            }
            guard trimmed.hasPrefix("let ") || trimmed.hasPrefix("var "),
                  let colon = trimmed.firstIndex(of: ":") else { continue }
            let name = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)..<colon])
                .trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty,
                  name.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "_") })
            else { continue }
            found.insert(name)
        }
        return found
    }

    /// The header names passed to `setValue(_:forHTTPHeaderField:)`.
    private static func headerNames(in source: String) -> [String] {
        let text = source as NSString
        let needle = "forHTTPHeaderField: \""
        var names: [String] = []
        var cursor = 0
        while cursor < text.length {
            let found = text.range(of: needle, range: NSRange(location: cursor, length: text.length - cursor))
            guard found.location != NSNotFound else { break }
            let start = found.location + found.length
            let rest = NSRange(location: start, length: text.length - start)
            let end = text.range(of: "\"", range: rest)
            guard end.location != NSNotFound else { break }
            names.append(text.substring(with: NSRange(location: start, length: end.location - start)))
            cursor = end.location + 1
        }
        return names
    }
}
