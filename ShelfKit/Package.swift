// swift-tools-version: 5.9
import PackageDescription

/// ShelfKit is everything in Shelf that isn't AppKit: the Spaces and shelves model, the Rules
/// engine, persistence, drag-and-drop planning and the licensing types the site shares with the app.
/// It builds and tests on Linux as well as macOS.
let package = Package(
    name: "ShelfKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ShelfKit", targets: ["ShelfKit"]),
    ],
    targets: [
        .target(
            name: "ShelfKit",
            path: "Sources/ShelfKit"
        ),
        .testTarget(
            name: "ShelfKitTests",
            dependencies: ["ShelfKit"],
            path: "Tests/ShelfKitTests"
        ),
    ]
)
