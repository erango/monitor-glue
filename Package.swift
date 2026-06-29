// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MonitorGlue",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MonitorGlue",
            path: "Sources/MonitorGlue"
        )
    ]
)
