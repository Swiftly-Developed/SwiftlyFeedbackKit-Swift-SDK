// swift-tools-version: 6.2
// SwiftlyFeedbackKit - Swift SDK for FeedbackKit
// https://github.com/Swiftly-Developed/SwiftlyFeedbackKit
// Copyright (c) 2025 Swiftly Workspace BV - MIT License

import PackageDescription

let package = Package(
    name: "SwiftlyFeedbackKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "SwiftlyFeedbackKit",
            targets: ["SwiftlyFeedbackKit"]
        ),
    ],
    targets: [
        .target(
            name: "SwiftlyFeedbackKit",
            path: "Sources/SwiftlyFeedbackKit",
            resources: [
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "GenerateStringCatalogSymbols")
            ]
        ),
        // Generates typed symbols from Resources/Localizable.xcstrings. This is
        // a plugin rather than Xcode's STRING_CATALOG_GENERATE_SYMBOLS build
        // setting because that setting is unreachable for a published SwiftPM
        // package — see the plugin source for the measurements.
        .plugin(
            name: "GenerateStringCatalogSymbols",
            capability: .buildTool(),
            path: "Plugins/GenerateStringCatalogSymbols"
        ),
        .testTarget(
            name: "SwiftlyFeedbackKitTests",
            dependencies: ["SwiftlyFeedbackKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
