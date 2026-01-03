// swift-tools-version: 6.2
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
    ]
)
