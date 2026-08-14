// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Koin",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Koin", targets: ["Koin"]),
        .library(name: "KoinSwiftUI", targets: ["KoinSwiftUI"])
    ],
    targets: [
        .target(name: "Koin"),
        .target(name: "KoinSwiftUI", dependencies: ["Koin"]),
        .testTarget(name: "KoinTests", dependencies: ["Koin"]),
        .testTarget(name: "KoinSwiftUITests", dependencies: ["KoinSwiftUI", "Koin"])
    ]
)
