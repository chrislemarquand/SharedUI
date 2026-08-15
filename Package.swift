// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
    ],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/SvenTiigi/WhatsNewKit.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "SharedUI",
            dependencies: [
                .product(name: "WhatsNewKit", package: "WhatsNewKit", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/SharedUI"
        )
    ]
)
