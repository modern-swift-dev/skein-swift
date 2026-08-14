# Koin for Swift

`Koin` is a small, type-safe dependency-injection container for Swift. It provides independently owned applications, lazy singletons, factories (including typed assisted factories), flat scopes, main-actor bindings, protocol bindings, typed qualifiers, structural validation, and source-aware resolution diagnostics.

## Install

Add this package as a dependency in Xcode or Swift Package Manager, then depend on the `Koin` product:

```swift
.product(name: "Koin", package: "koin4swift")
```

## Quick start

Bindings declare their exposed type and receive a `Resolver` for their own dependencies. A `single` is created once on first use; a `factory` creates a new value for every resolution.

```swift
import Koin

protocol HTTPClient { }
final class URLSessionClient: HTTPClient { }

final class UserService {
    init(client: any HTTPClient) { }
}

let appModule = module {
    single((any HTTPClient).self) { _ in URLSessionClient() }
    factory(UserService.self) { resolver in
        UserService(client: try resolver.get())
    }
}

try startKoin {
    modules(appModule)
}

let service: UserService = try get()
stopKoin()
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

## Runnable examples

The [`Examples`](Examples/README.md) package contains independent, executable use cases for:

- singleton and factory lifetimes;
- dependency chains and module composition;
- protocol-oriented registrations;
- qualified bindings;
- lifecycle and provider-error handling;
- main-actor services, structural validation, and explicit startup validation;
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

These examples depend on the local checkout of Koin, so they also serve as compile-checked usage references while the API evolves.
