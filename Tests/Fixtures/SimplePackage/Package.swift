// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SimplePackage",
    targets: [
        .target(name: "AppCore"),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
    ]
)
