---
title: "Skein examples"
description: "Compile-checked Skein examples from this repository."
---

Examples

# Code that this repository compiles.

Each target in `Examples` uses the local Skein checkout. These blocks are read from the source files at build time, not copied into the site by hand.

## BasicUsage

Owned SkeinApplication, lazy singletons, factories, assisted factories, and a typed scope.

Run: `swift run --package-path Examples BasicUsage`

[Open source file ↗](https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main/Examples/Sources/BasicUsage/main.swift)

Examples/Sources/BasicUsage/main.swift

<!-- include: Examples/Sources/BasicUsage/main.swift -->

## ModularComposition

Feature modules and a protocol registration for a live API client.

Run: `swift run --package-path Examples ModularComposition`

[Open source file ↗](https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main/Examples/Sources/ModularComposition/main.swift)

Examples/Sources/ModularComposition/main.swift

<!-- include: Examples/Sources/ModularComposition/main.swift -->

## QualifiedBindings

Multiple values of the same type, separated by qualifiers.

Run: `swift run --package-path Examples QualifiedBindings`

[Open source file ↗](https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main/Examples/Sources/QualifiedBindings/main.swift)

Examples/Sources/QualifiedBindings/main.swift

<!-- include: Examples/Sources/QualifiedBindings/main.swift -->

## ErrorHandling

Provider failures wrapped in SkeinResolutionError and retried singletons.

Run: `swift run --package-path Examples ErrorHandling`

[Open source file ↗](https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main/Examples/Sources/ErrorHandling/main.swift)

Examples/Sources/ErrorHandling/main.swift

<!-- include: Examples/Sources/ErrorHandling/main.swift -->

## MainActorValidation

MainActor bindings, eager roots, and async startup validation.

Run: `swift run --package-path Examples MainActorValidation`

[Open source file ↗](https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main/Examples/Sources/MainActorValidation/MainActorValidation.swift)

Examples/Sources/MainActorValidation/MainActorValidation.swift

<!-- include: Examples/Sources/MainActorValidation/MainActorValidation.swift -->

## TestingExampleTests

A production module replaced with a hand-written fake in an isolated test container.

Run: `swift test --package-path Examples`

[Open source file ↗](https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main/Examples/Tests/TestingExampleTests/TestingExampleTests.swift)

Examples/Tests/TestingExampleTests/TestingExampleTests.swift

<!-- include: Examples/Tests/TestingExampleTests/TestingExampleTests.swift -->

[Browse all examples ↗](https://github.com/modern-swift-dev/skein-swift/tree/main/Examples)
