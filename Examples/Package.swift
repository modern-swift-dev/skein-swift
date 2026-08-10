// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KoinExamples",
    dependencies: [
        .package(path: "..")
    ],
    targets: [
        .executableTarget(
            name: "BasicUsage",
            dependencies: [.product(name: "Koin", package: "koin4swift")]
        ),
        .executableTarget(
            name: "ModularComposition",
            dependencies: [.product(name: "Koin", package: "koin4swift")]
        ),
        .executableTarget(
            name: "QualifiedBindings",
            dependencies: [.product(name: "Koin", package: "koin4swift")]
        ),
        .executableTarget(
            name: "ErrorHandling",
            dependencies: [.product(name: "Koin", package: "koin4swift")]
        ),
        .testTarget(
            name: "TestingExampleTests",
            dependencies: [.product(name: "Koin", package: "koin4swift")]
        )
    ]
)
