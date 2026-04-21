// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "InspectKit",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "InspectKit",
            targets: ["InspectKit"]
        ),
        .library(
            name: "InspectKitMock",
            targets: ["InspectKitMock"]
        ),
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        // Shared internal target — not a product; used by both InspectKit and InspectKitMock
        .target(
            name: "InspectKitCore",
            dependencies: [],
            path: "Sources/InspectKitCore"
        ),
        // Network inspector (unchanged public API)
        .target(
            name: "InspectKit",
            dependencies: ["InspectKitCore"],
            path: "Sources/InspectKit"
        ),
        // Mock/stub framework
        .target(
            name: "InspectKitMock",
            dependencies: ["InspectKitCore"],
            path: "Sources/InspectKitMock"
        ),
    ]
)
