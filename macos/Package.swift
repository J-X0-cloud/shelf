// swift-tools-version: 5.9
import PackageDescription

/// The menu-bar app. Everything that isn't AppKit or SwiftUI lives in ../ShelfKit, which also
/// builds and tests on Linux; this package needs macOS 13+ and Xcode 15 or later.
let package = Package(
    name: "Shelf",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Shelf", targets: ["Shelf"]),
    ],
    dependencies: [
        .package(path: "../ShelfKit"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4"),
    ],
    targets: [
        .executableTarget(
            name: "Shelf",
            dependencies: [
                .product(name: "ShelfKit", package: "ShelfKit"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Shelf"
        ),
        .testTarget(
            name: "ShelfTests",
            dependencies: [
                "Shelf",
                .product(name: "ShelfKit", package: "ShelfKit"),
            ],
            path: "Tests/ShelfTests"
        ),
    ]
)
