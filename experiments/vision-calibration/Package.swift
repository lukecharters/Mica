// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "vision-calibration",
    platforms: [.macOS("27.0")],
    targets: [
        .executableTarget(name: "vcal", path: "Sources/vcal"),
    ],
    swiftLanguageModes: [.v6]
)
