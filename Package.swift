// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Offscript",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "1.1.1"),
    ],
    targets: [
        // Pure logic, unit tested.
        .target(name: "OffscriptCore"),
        // macOS glue: event tap, audio, WhisperKit, paste, menu bar.
        .executableTarget(
            name: "Offscript",
            dependencies: [
                "OffscriptCore",
                .product(name: "WhisperKit", package: "WhisperKit"),
            ]
        ),
        .testTarget(name: "OffscriptCoreTests", dependencies: ["OffscriptCore"]),
    ],
    swiftLanguageModes: [.v5]
)
