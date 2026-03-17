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
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.24.0"),
    ],
    targets: [
        .executableTarget(
            name: "swiftcontext",
            dependencies: [
                "SwiftContextKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "SwiftContextKit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
        .testTarget(
            name: "SwiftContextKitTests",
            dependencies: ["SwiftContextKit"]
        ),
    ]
)
