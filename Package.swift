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
        .library(name: "SkeinSwiftUI", targets: ["SkeinSwiftUI"]),
        .library(name: "SkeinVapor", targets: ["SkeinVapor"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-docc-plugin",
            exact: "1.5.0"
        ),
        .package(
            url: "https://github.com/vapor/vapor.git",
            exact: "4.122.0"
        )
    ],
    targets: [
        .target(name: "Skein"),
        .target(name: "SkeinSwiftUI", dependencies: ["Skein"]),
        .target(
            name: "SkeinVapor",
            dependencies: [
                "Skein",
                .product(
                    name: "Vapor",
                    package: "vapor",
                    condition: .when(platforms: [.macOS, .linux])
                )
            ]
        ),
        .testTarget(name: "SkeinTests", dependencies: ["Skein"]),
        .testTarget(name: "SkeinSwiftUITests", dependencies: ["SkeinSwiftUI", "Skein"]),
        .testTarget(
            name: "SkeinVaporTests",
            dependencies: [
                "SkeinVapor",
                "Skein",
                .product(
                    name: "Vapor",
                    package: "vapor",
                    condition: .when(platforms: [.macOS, .linux])
                )
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
