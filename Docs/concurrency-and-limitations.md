# Concurrency and isolation

[Documentation index](README.md)

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
- Cancellation of one waiter does not cancel shared singleton creation.
- Task-local resolution paths detect cycles across actor hops, while a container-wide wait graph detects cycles between independently started async creations.
- Skein protects container state but does not make registered objects internally thread-safe.
- Lifetimes are lazy singleton, factory, and flat typed scope; nested scopes, reflection, property injection, and macros are not provided.
- `SkeinSwiftUI` is the optional Apple-platform adapter.
