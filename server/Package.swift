// swift-tools-version: 5.9
import PackageDescription

/// The shelfapp.com server: the static product site, the changelog and Sparkle appcast rendered
/// from one list of releases, and the checkout and license endpoints the macOS app calls.
let package = Package(
    name: "ShelfServer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ShelfServer", targets: ["ShelfServer"]),
        .library(name: "ShelfWeb", targets: ["ShelfWeb"]),
    ],
    dependencies: [
        .package(path: "../ShelfKit"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.5.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0" ..< "5.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "ShelfWeb",
            dependencies: [
                .product(name: "ShelfKit", package: "ShelfKit"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            path: "Sources/ShelfWeb"
        ),
        .executableTarget(
            name: "ShelfServer",
            dependencies: ["ShelfWeb"],
            path: "Sources/ShelfServer"
        ),
        .testTarget(
            name: "ShelfWebTests",
            dependencies: [
                "ShelfWeb",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ],
            path: "Tests/ShelfWebTests"
        ),
    ]
)
