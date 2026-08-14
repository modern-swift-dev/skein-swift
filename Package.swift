// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Skein",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Skein", targets: ["Skein"]),
        .library(name: "SkeinSwiftUI", targets: ["SkeinSwiftUI"])
    ],
    targets: [
        .target(name: "Skein"),
        .target(name: "SkeinSwiftUI", dependencies: ["Skein"]),
        .testTarget(name: "SkeinTests", dependencies: ["Skein"]),
        .testTarget(name: "SkeinSwiftUITests", dependencies: ["SkeinSwiftUI", "Skein"])
    ]
)
