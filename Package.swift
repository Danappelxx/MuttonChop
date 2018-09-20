// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "MuttonChop",
    products: [
        .library(name: "MuttonChop", targets: ["MuttonChop"])
    ],
    dependencies: [
    .package(url: "https://gitlab.com/katalysis-public/Zewo.git", from: "0.16.2")
    ],
    targets: [
        .target(name: "MuttonChop", dependencies: ["Zewo"]),
        .testTarget(name: "MuttonChopTests", dependencies: ["MuttonChop"])
    ]
)
