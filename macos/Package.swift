// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Shelf",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Shelf", targets: ["Shelf"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.4"),
    ],
    targets: [
        .executableTarget(
            name: "Shelf",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Shelf",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
            ]
        ),
        .testTarget(
            name: "ShelfTests",
            dependencies: ["Shelf"],
            path: "Tests/ShelfTests"
        ),
    ]
)
