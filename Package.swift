// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalWhisper",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.1.1"),
    ],
    targets: [
        // Pure logic, unit tested.
        .target(name: "LocalWhisperCore"),
        // macOS glue: event tap, audio, WhisperKit, paste, menu bar.
        .executableTarget(
            name: "LocalWhisper",
            dependencies: [
                "LocalWhisperCore",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ]
        ),
        .testTarget(name: "LocalWhisperCoreTests", dependencies: ["LocalWhisperCore"]),
    ],
    swiftLanguageModes: [.v5]
)
