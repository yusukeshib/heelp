// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mend",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "mend",
            path: "Sources/mend"
        )
    ]
)
