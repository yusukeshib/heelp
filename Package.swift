// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Jogen",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Jogen",
            path: "Sources/Jogen"
        )
    ]
)
