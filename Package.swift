// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Closetalk",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.1.1"),
    ],
    targets: [
        // Pure logic, unit tested.
        .target(name: "ClosetalkCore"),
        // macOS glue: event tap, audio, WhisperKit, paste, menu bar.
        .executableTarget(
            name: "Closetalk",
            dependencies: [
                "ClosetalkCore",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ]
        ),
        .testTarget(name: "ClosetalkCoreTests", dependencies: ["ClosetalkCore"]),
    ],
    swiftLanguageModes: [.v5]
)
