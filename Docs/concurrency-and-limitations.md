# Concurrency and limitations

[Documentation index](README.md)

Koin serializes dependency resolution within its container. Concurrent calls that resolve the same `single` are safe: the provider is run once after a successful creation, and all callers receive the cached result. Factories still invoke their provider for every resolution.

```swift
import Dispatch
import Koin

final class SharedCache { }

let definitions = module {
    single(SharedCache.self) { _ in SharedCache() }
}

try startKoin { modules(definitions) }

DispatchQueue.concurrentPerform(iterations: 64) { _ in
    let cache: SharedCache = try! get()
    _ = cache
}
```

The `try!` above is only suitable for this deliberately configured example. Production code should propagate or handle errors from `get`.

## Current boundaries

- The public API operates through one global container: `startKoin`, `get`, and `stopKoin`.
- There are only two lifetimes: lazy singleton and factory; scopes and eager creation are not available.
- Koin protects its own registration, resolution, and singleton-cache state. It does not make the objects you register thread-safe; choose synchronization appropriate to each service.
- Dependencies are registered explicitly through `module`, `single`, and `factory`. There is no automatic constructor discovery or property injection.
- Circular dependencies are detected during resolution and throw an error.
- There are no built-in adapters documented here for application frameworks, SDKs, mock generators, or other external technologies.

For operational failure cases, see [lifecycle and errors](lifecycle-and-errors.md). For lifetime choice, see [bindings and lifetimes](bindings-and-lifetimes.md).
