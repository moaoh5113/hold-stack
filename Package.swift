// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "HoldStack",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HoldCore"),
        .executableTarget(name: "HoldStack", dependencies: ["HoldCore"]),
        .executableTarget(name: "HoldCoreCheck", dependencies: ["HoldCore"]),
    ]
)
