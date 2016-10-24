import PackageDescription

let package = Package(
    name: "MuttonChop",
    dependencies: [
        .Package(url: "https://github.com/Zewo/Axis.git", majorVersion: 0, minor: 14)
    ]
)
