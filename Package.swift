// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "MuttonChop",
    products: [
        .library(name: "MuttonChop", targets: ["MuttonChop"])
    ],
    dependencies: [
    .package(url: "https://github.com/Zewo/Zewo.git", .branch("0.16.1"))
    ],
    targets: [
        .target(name: "MuttonChop", dependencies: ["Zewo"]),
        .testTarget(name: "MuttonChopTests", dependencies: ["MuttonChop"])
    ]
)
