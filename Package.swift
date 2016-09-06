import PackageDescription

let package = Package(
    name: "MuttonChop",
    dependencies: [
        // Test dependency
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 12)
    ]
)
