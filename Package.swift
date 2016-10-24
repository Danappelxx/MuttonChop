import PackageDescription
#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

// if there is a file at /tmp/testing, add JSON as a test dependency
let testing = access("/tmp/testing", F_OK) != -1

let package = Package(
    name: "MuttonChop",
    dependencies: [
        .Package(url: "https://github.com/Zewo/Axis.git", majorVersion: 0, minor: 14)
    ]
)
