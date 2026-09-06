---
title: "Getting started with Skein"
description: "Register, resolve, and validate a small Skein dependency graph."
---

Getting started

# Register the graph you mean to run.

Skein modules declare what consumers resolve. Providers receive a resolver for their own dependencies. The normal APIs are MainActor-isolated, so they work naturally with UI services that are not Sendable.

## 1. Check requirements and add the package

Skein uses Swift 6. The package supports macOS 15, iOS 17, tvOS 17, watchOS 10, and visionOS 1. Add the versioned package dependency in Xcode or your Swift Package Manager manifest, then depend on the `Skein` product.

Package.swift, Skein {{version}}

```swift
dependencies: [
    .package(url: "https://github.com/modern-swift-dev/skein-swift.git", from: "{{version}}")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [.product(name: "Skein", package: "skein-swift")]
    )
]
```

## 2. Define a module

Register the type that callers ask for. When a service depends on a protocol, register the protocol existential rather than the implementation type.

An application module

```swift
import Foundation
import Skein

protocol Clock { func now() -> Date }
final class SystemClock: Clock {
    func now() -> Date { Date() }
}
final class GreetingService {
    private let clock: any Clock
    init(clock: any Clock) { self.clock = clock }
}

let appModule = module {
    single((any Clock).self, provider: { _ in SystemClock() })
    factory(GreetingService.self, using: GreetingService.init)
}
```

## 3. Start and resolve

Install the global application before calling `get()`. Both startup and resolution can throw.

Application lifetime

```swift
try startSkein { appModule }

let greetingService: GreetingService = try get()
let clock = try get((any Clock).self)

// Call during application shutdown or test teardown.
stopSkein()
```

## 4. Validate declared startup roots

A structural root checks constructor edges without running its provider. An eager root resolves after structural validation passes. Put the root policy on the binding that owns the startup work.

Async validated startup

```swift
let featureModule = module {
    single(APIClient.self, using: APIClient.init)
    factory(FeatureService.self, using: FeatureService.init)
        .root(.eager)
}

let application = try await SkeinApplication(validation: .declaredRoots) {
    featureModule
}
```

single

`get()` → one cached value

The provider runs on the first successful resolution. Later lookups return that value.

factory

`get()` → new value

The provider runs for every resolution. Its dependencies may still be singletons.

Choose a lifetime at registration time. Skein keeps that decision visible in the module.

The full guide is kept with the module source: [GettingStarted.md](https://raw.githubusercontent.com/modern-swift-dev/skein-swift/main/Sources/Skein/Skein.docc/GettingStarted.md).
