// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SkeinExamples",
    platforms: [
        .macOS(.v15),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1)
    ],
    dependencies: [
        .package(name: "Skein", path: "..")
    ],
    targets: [
        .executableTarget(
            name: "BasicUsage",
            dependencies: [.product(name: "Skein", package: "Skein")]
        ),
        .executableTarget(
            name: "ModularComposition",
            dependencies: [.product(name: "Skein", package: "Skein")]
        ),
        .executableTarget(
            name: "QualifiedBindings",
            dependencies: [.product(name: "Skein", package: "Skein")]
        ),
        .executableTarget(
            name: "ErrorHandling",
            dependencies: [.product(name: "Skein", package: "Skein")]
        ),
        .executableTarget(
            name: "MainActorValidation",
            dependencies: [.product(name: "Skein", package: "Skein")]
        ),
        .testTarget(
            name: "TestingExampleTests",
            dependencies: [.product(name: "Skein", package: "Skein")]
        )
    ]
)
