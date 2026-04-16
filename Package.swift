// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "InspectKit",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "InspectKit",
            targets: ["InspectKit"]
        )
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        .target(
            name: "InspectKit",
            dependencies: [],
            path: "Sources/InspectKit",
            swiftSettings: [
                .unsafeFlags(["-suppress-warnings"], .when(configuration: .debug))
            ]
        )
    ]
)
