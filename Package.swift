// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "openvireo-examples-swift",
    platforms: [.macOS(.v13)],
    dependencies: [
        // The Swift binding of the OpenVireo core: OpenVireoCore.xcframework from the core's release
        // plus the UniFFI Swift API over it (github.com/openvireo/openvireo-swift)
        .package(url: "https://github.com/openvireo/openvireo-swift", from: "1.2.2"),
    ],
    targets: [
        .executableTarget(
            name: "Examples",
            dependencies: [.product(name: "OpenVireoRustCore", package: "openvireo-swift")]),
    ]
)
