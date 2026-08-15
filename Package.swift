// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Heelp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Heelp",
            path: "Sources/Heelp"
        )
    ]
)
