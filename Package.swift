// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swiftcontext",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "swiftcontext", targets: ["swiftcontext"]),
        .library(name: "SwiftContextKit", targets: ["SwiftContextKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "swiftcontext",
            dependencies: ["SwiftContextKit"]
        ),
        .target(
            name: "SwiftContextKit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftContextKitTests",
            dependencies: ["SwiftContextKit"]
        ),
    ]
)
