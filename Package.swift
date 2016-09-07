import PackageDescription

let package = Package(
    name: "MuttonChop",
    dependencies: [
        .Package(url: "https://github.com/Zewo/StructuredData.git", majorVersion: 0, minor: 10),
        // Test dependency
        .Package(url: "https://github.com/Zewo/JSON.git", majorVersion: 0, minor: 12),
    ]
)
