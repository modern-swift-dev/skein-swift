# Concurrency and isolation

[Documentation index](<doc:Skein>)

Skein is MainActor-first. The unprefixed `module`, `single`, `factory`, `scoped`, `instance`, and `get` APIs are MainActor-isolated, which makes UI-oriented, non-`Sendable` graphs concise and compiler checked.

```swift
@MainActor final class AppPresenter { }

let uiModule = module {
    single(AppPresenter.self, using: AppPresenter.init)
}

@MainActor func present() throws {
    let presenter: AppPresenter = try get()
    _ = presenter
}
```

## Explicit nonisolated bindings

Use the `nonisolated...` APIs when a dependency must be resolved from concurrent code. Services, assisted arguments, dependencies, providers, and disposal callbacks must be `Sendable`.

```swift
struct SharedCache: Sendable { }

let cacheModule = module {
    nonisolatedSingle(SharedCache.self, using: SharedCache.init)
}

let cache: SharedCache = try application.nonisolatedGet()
```

A MainActor binding may depend on MainActor or nonisolated bindings. A nonisolated binding may depend only on nonisolated bindings.

## Custom global actors

App-defined global actors use asynchronous registration and resolution. The declared actor must match the provider's compiler-retained dynamic isolation, and all values crossing the boundary are `Sendable`.

```swift
@globalActor actor DatabaseActor {
    static let shared = DatabaseActor()
}

struct Database: Sendable { }

let databaseModule = module {
    actorSingle(Database.self, isolatedTo: DatabaseActor.self, provider: {
        @DatabaseActor _ in Database()
    })
}

let database: Database = try await application.actorGet()
```

Custom-actor constructor registrations may resolve Sendable dependencies across isolation domains through async `actorGet`. Skein does not support registrations isolated to an individual actor instance.

## Runtime guarantees and boundaries

- Concurrent async singleton resolution coalesces first creation; a failed creation is retried later.
- Cancellation of one waiter does not cancel shared singleton creation. A cancelled waiter on a shared custom-actor single or scoped binding stops waiting at once and throws a bare `CancellationError`, not a `SkeinResolutionError`, so `catch is CancellationError` works. The creation keeps running for the remaining waiters, and its result is still cached and disposed as usual.
- Synchronous providers (`single`, `factory`, `scoped`, and their `nonisolated...` counterparts) run while the owning application or scope is locked. This guarantees that a single is created exactly once, but a slow synchronous provider blocks every other synchronous lookup on that application or scope, including main-actor lookups of unrelated bindings, and all factory resolutions on it are serialized. Keep synchronous providers fast, and move slow initialization into a custom-actor binding (`actorSingle` or `actorScoped`), whose creation runs outside the lock.
- Task-local resolution paths detect cycles across actor hops, while a container-wide wait graph detects cycles between independently started async creations.
- Skein protects container state but does not make registered objects internally thread-safe.
- Lifetimes are lazy singleton, factory, and flat typed scope; nested scopes, reflection, property injection, and macros are not provided.
- `SkeinSwiftUI` is the optional Apple-platform adapter.
