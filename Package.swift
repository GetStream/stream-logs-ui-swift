// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "StreamLogsUI",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "StreamLogsUI",
            targets: ["StreamLogsUI"]
        )
    ],
    targets: [
        // No dependencies, so that it can be used with any logging library,
        // and so that apps embedding it in a framework don't duplicate other packages.
        .target(
            name: "StreamLogsUI"
        ),
        .testTarget(
            name: "StreamLogsUITests",
            dependencies: ["StreamLogsUI"]
        )
    ]
)
