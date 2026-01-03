// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftlyFeedbackKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .visionOS(.v1)
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
            path: "Sources/SwiftlyFeedbackKit"
        ),
        .testTarget(
            name: "SwiftlyFeedbackKitTests",
            dependencies: ["SwiftlyFeedbackKit"]
        ),
    ]
)
