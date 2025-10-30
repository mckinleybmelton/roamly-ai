// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RoamlyAI",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "RoamlyAI",
            targets: ["RoamlyAI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/google-ai-edge/ai-edge-swift.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "RoamlyAI",
            dependencies: [
                .product(name: "AIEdge", package: "ai-edge-swift")
            ]),
    ]
)
