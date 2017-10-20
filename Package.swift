// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "MuttonChop",
    products: [
        .library(name: "MuttonChop", targets: ["MuttonChop"])
    ],
    dependencies: [
        .package(url: "https://github.com/ratranqu/Zewo.git", .branch("swift-4"))
    ],
    targets: [
        .target(name: "MuttonChop", dependencies: ["Zewo"]),
        .testTarget(name: "MuttonChopTests", dependencies: ["MuttonChop"])
    ]
)
