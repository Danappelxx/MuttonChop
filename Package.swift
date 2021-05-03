// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "MuttonChop",
    products: [
        .library(name: "MuttonChop", targets: ["MuttonChop"]),
        .executable(name: "generate-tests", targets: ["GenerateTests"])
    ],
    dependencies: [],
    targets: [
        .target(name: "MuttonChop"),
        .executableTarget(name: "GenerateTests", dependencies: ["MuttonChop"]),
        .testTarget(
            name: "MuttonChopTests",
            dependencies: ["MuttonChop"],
            resources: [
                .process("Tests/MuttonChopTests/Fixtures/conversation.mustache"),
                .process("Tests/MuttonChopTests/Fixtures/EmptyTemplate.mustache"),
                .process("Tests/MuttonChopTests/Fixtures/greeting.mustache"),
                .process("Tests/MuttonChopTests/Fixtures/NotATemplate"),
            ]),
        .testTarget(name: "SpecTests", dependencies: ["MuttonChop"])
    ]
)
