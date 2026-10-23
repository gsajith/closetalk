// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Closetalk",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.1.1"),
        // Pinned: the signing steps in scripts/build-app.sh follow this version's framework layout.
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
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
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(name: "ClosetalkCoreTests", dependencies: ["ClosetalkCore"]),
    ],
    swiftLanguageModes: [.v5]
)
