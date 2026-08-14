# Concurrency and limitations

[Documentation index](README.md)

Skein serializes dependency resolution within each application. Concurrent calls that resolve the same `single` are safe: the provider is run once after a successful creation, and all callers receive the cached result. Factories still invoke their provider for every resolution.

```swift
import Dispatch
import Skein

final class SharedCache { }

let definitions = module {
    single(SharedCache.self) { _ in SharedCache() }
}

try startSkein { modules(definitions) }

DispatchQueue.concurrentPerform(iterations: 64) { _ in
    let cache: SharedCache = try! get()
    _ = cache
}
```

The `try!` above is only suitable for this deliberately configured example. Production code should propagate or handle errors from `get`.

## Main-actor services

For dependencies confined to the UI actor, register an actor-isolated provider with `mainActorSingle` or `mainActorFactory`, then resolve it from `@MainActor` code using `mainActorGet`.

```swift
@MainActor final class AppPresenter { }

let uiModule = module {
    mainActorSingle(AppPresenter.self) { _ in AppPresenter() }
}

@MainActor func present() throws {
    let presenter: AppPresenter = try mainActorGet()
    _ = presenter
}
```

The ordinary `get` and `Resolver.get` reject these bindings with `.mainActorBindingRequiresMainActor(type:qualifier:)`. This rule also applies after a main-actor singleton is cached, so callers do not need `MainActor.assumeIsolated` or `@unchecked Sendable` wrappers. A main-actor provider may use `resolver.get` for ordinary dependencies and `resolver.mainActorGet` for actor-isolated ones. An ordinary provider cannot resolve a main-actor dependency.

## Current boundaries

- `SkeinApplication` owns an independent container. The global `startSkein`, `get`, `mainActorGet`, and `stopSkein` APIs forward to one optional default application. `isSkeinStarted` is a safe lifecycle snapshot, not a startup lock.
- Lifetimes are lazy singleton, factory, and flat typed scope. Nested scopes, async providers, lazy resolver handles, and task-local resolution are not available.
- Skein protects its own registration, resolution, and singleton-cache state. It does not make the objects you register thread-safe; choose synchronization appropriate to each service.
- Dependencies are registered explicitly through `module`, `single`, `factory`, and `scoped`. Constructor registration supports explicitly passed initializer references with up to four unqualified parameters; there is no reflection, automatic discovery, property injection, or macros.
- Circular dependencies are detected during resolution and throw an error.
- `SkeinSwiftUI` is an optional adapter for modern Apple platforms. There are no other built-in adapters, SDK integrations, or mock generators.

For operational failure cases, see [lifecycle and errors](lifecycle-and-errors.md). For lifetime choice, see [bindings and lifetimes](bindings-and-lifetimes.md).
