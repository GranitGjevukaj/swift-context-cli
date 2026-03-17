// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swiftcontext",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "swiftcontext", targets: ["swiftcontext"]),
        .library(name: "SwiftContextKit", targets: ["SwiftContextKit"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "swiftcontext",
            dependencies: ["SwiftContextKit"]
        ),
        .target(
            name: "SwiftContextKit",
            dependencies: []
        ),
        .testTarget(
            name: "SwiftContextKitTests",
            dependencies: ["SwiftContextKit"]
        ),
    ]
)
