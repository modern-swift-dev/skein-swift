// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Koin",
    products: [
        .library(name: "Koin", targets: ["Koin"])
    ],
    targets: [
        .target(name: "Koin"),
        .testTarget(name: "KoinTests", dependencies: ["Koin"])
    ]
)
