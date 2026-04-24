// swift-tools-version: 6.2
// SwiftlyFeedbackKit - Swift SDK for FeedbackKit
// https://github.com/Swiftly-Developed/SwiftlyFeedbackKit
// Copyright (c) 2025 Swiftly Developed - MIT License

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
            ]
        ),
        .testTarget(
            name: "SwiftlyFeedbackKitTests",
            dependencies: ["SwiftlyFeedbackKit"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
