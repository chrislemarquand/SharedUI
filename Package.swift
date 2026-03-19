// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"])
    ],
    targets: [
        .target(
            name: "SharedUI",
            path: "Sources/SharedUI"
        )
    ]
)
