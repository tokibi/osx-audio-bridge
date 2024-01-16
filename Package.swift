// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OSXAudioBridge",
    platforms: [.macOS("13.1")],
    products: [
        .executable(name: "OSXAudioBridgeCLI", targets: ["OSXAudioBridgeCLI"]),
        .library(name: "CaptureEngine", targets: ["CaptureEngine"]),
        .library(name: "CaptureServer", targets: ["CaptureServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
        .package(url: "https://github.com/kylef/Spectre.git", from: "0.10.0"),
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.21.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.62.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "OSXAudioBridgeCLI",
            dependencies: [
                "CaptureEngine",
                "CaptureServer",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "CaptureEngine",
            dependencies: [
            ]
        ),
        .target(
            name: "CaptureServer",
            dependencies: [
                "CaptureEngine",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "NIO", package: "swift-nio"),
                // .product(name: "NIOHTTP2", package: "swift-nio-http2"),
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
