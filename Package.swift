// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ppp",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ppp",
            path: "Sources/ppp"
        )
    ]
)
