# Koin for Swift

`Koin` is a small, type-safe dependency-injection container for Swift. It provides modules, lazily created singletons, and factories.

## Install

Add this package as a dependency in Xcode or Swift Package Manager, then depend on the `Koin` product:

```swift
.product(name: "Koin", package: "koin4swift")
```

## Define a module

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
```

## Start and resolve

Start the container once with one or more modules. Resolve values globally with `get()`, or inside a binding through its resolver. Call `stopKoin()` when the application or test container is no longer needed.

```swift
try startKoin {
    modules(appModule)
}

let service: UserService = try get()
stopKoin()
```

## Qualifiers

Use a `KoinQualifier` when the same type has more than one binding. Qualifier identity includes both its type and value.

```swift
enum ClientKind: KoinQualifier {
    case primary
    case background
}

let clients = module {
    single((any HTTPClient).self, qualifier: ClientKind.primary) { _ in URLSessionClient() }
    single((any HTTPClient).self, qualifier: ClientKind.background) { _ in URLSessionClient() }
}

let client = try get((any HTTPClient).self, qualifier: ClientKind.primary)
```

## Errors

All resolution and lifecycle operations throw `KoinError` where applicable: calling `get` before startup, starting twice, duplicate or missing bindings, circular dependency resolution, and an internal resolved-type mismatch. Errors thrown by a binding provider are passed through unchanged. A failed singleton provider is not cached and will be attempted again on the next resolution.
