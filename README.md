# Skein for Swift

`Skein` is a small, type-safe dependency-injection container for Swift. Its default API is MainActor-isolated, with explicit Sendable nonisolated and custom-global-actor alternatives.

## Why Skein?

A skein is a length of thread gathered into a connected bundle. The name reflects how this library brings the individual threads of an application's dependency graph together into one explicit, inspectable composition.

## Install

Add this package as a dependency in Xcode or Swift Package Manager, then depend on the `Skein` product:

```swift
.product(name: "Skein", package: "skein-swift")
```

Vapor 4 applications can instead add the `SkeinVapor` product alongside `Skein`. The integration is available on macOS 15 and Linux and pins Vapor 4.122.0.

## Quick start

Bindings declare their exposed type and receive a `Resolver` for their own dependencies. A `single` is created once on first use; a `factory` creates a new value for every resolution.

```swift
import Skein

protocol HTTPClient { }
final class URLSessionClient: HTTPClient { }

final class UserService {
    init(client: any HTTPClient) { }
}

let appModule = module {
    single((any HTTPClient).self, provider: { _ in URLSessionClient() })
    factory(UserService.self, using: UserService.init)
}

try startSkein {
    appModule
}

let service: UserService = try get()
stopSkein()
```

All setup and resolution operations that can fail use Swift error handling, so call them with `try` and handle failures appropriate to your application.

## Documentation

Start with the [documentation index](Docs/README.md), or jump directly to a focused guide:

- [Getting started](Docs/getting-started.md)
- [Bindings and lifetimes](Docs/bindings-and-lifetimes.md)
- [Modules and protocol bindings](Docs/modules-and-protocol-bindings.md)
- [Qualifiers](Docs/qualifiers.md)
- [Applications, assisted factories, scopes, and disposal](Docs/ergonomics.md)
- [Lifecycle, validation, and errors](Docs/lifecycle-and-errors.md)
- [Graph validation and migration](Docs/migration-main-actor-validation.md)
- [Testing with manual doubles](Docs/testing.md)
- [Concurrency and main-actor bindings](Docs/concurrency-and-limitations.md)
- [Vapor integration](Docs/vapor.md)

## Runnable examples

The [`Examples`](Examples/README.md) package contains independent, executable use cases for:

- singleton and factory lifetimes;
- dependency chains and module composition;
- protocol-oriented registrations;
- qualified bindings;
- lifecycle and provider-error handling;
- MainActor-first services, binding-owned roots, and async startup validation;
- test isolation and hand-written fakes.

Run any example directly from the repository root:

```sh
swift run --package-path Examples BasicUsage
swift run --package-path Examples ModularComposition
swift run --package-path Examples QualifiedBindings
swift run --package-path Examples ErrorHandling
swift run --package-path Examples MainActorValidation
swift test --package-path Examples
```

These examples depend on the local checkout of Skein, so they also serve as compile-checked usage references while the API evolves.
