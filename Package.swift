// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OSXScreenBridge",
    platforms: [.macOS("13.1")],
    products: [
        .executable(name: "OSXScreenBridgeCLI", targets: ["OSXScreenBridgeCLI"]),
        .library(name: "CaptureEngine", targets: ["CaptureEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.10.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "OSXScreenBridgeCLI",
            dependencies: [
                "CaptureEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "CaptureEngine",
            dependencies: [

            ]
        ),
        .testTarget(
            name: "CaptureEngineTest",
            dependencies: [
                "CaptureEngine",
                "Spectre",
            ]
        ),
    ]
)
