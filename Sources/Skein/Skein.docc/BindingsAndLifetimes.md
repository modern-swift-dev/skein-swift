# Bindings and lifetimes

[Documentation index](<doc:Skein>)

Root registrations are either a `single` or a `factory`. A `scoped` registration is cached once per active typed scope; see <doc:ApplicationsAssistedFactoriesScopesAndDisposal>.

| Binding | Provider runs | Result |
| --- | --- | --- |
| `single` | At the first successful resolution | The same instance/value is returned for later resolutions. |
| `factory` | At every resolution | A new value is returned each time. |

```swift
import Foundation
import Skein

final class SessionStore { }

final class RequestID {
    let value = UUID()
}

let module = module {
    single(SessionStore.self, using: SessionStore.init)
    factory(RequestID.self, using: RequestID.init)
}

try startSkein { module }

let firstStore: SessionStore = try get()
let secondStore: SessionStore = try get()
// firstStore === secondStore

let firstID: RequestID = try get()
let secondID: RequestID = try get()
// firstID !== secondID
```

Singletons are lazy: registering a `single` does not create it. The provider runs only when that binding is first resolved successfully. If its provider throws, no singleton is cached; the next lookup tries the provider again.

Use `single` for shared, stable dependencies such as configuration, a client, or a cache. Use `factory` for short-lived values whose construction should be repeated. Dependencies of a factory may still be singletons.

```swift
final class APIClient { }

final class ProfileLoader {
    init(client: APIClient) { }
}

let feature = module {
    single(APIClient.self, using: APIClient.init)
    factory(ProfileLoader.self, using: ProfileLoader.init)
}
```

## Constructor registrations

When a type can be constructed entirely from unqualified dependencies, use `using:`. Parameter packs support any constructor arity and record every dependency edge for structural validation.

```swift
final class APIClient { }
final class ProfileLoader {
    init(client: APIClient) { }
}

let feature = module {
    single(APIClient.self, using: APIClient.init)
    factory(ProfileLoader.self, using: ProfileLoader.init)
}
```

The exposed service type may be a protocol existential. Use a closure registration for qualified dependencies. Assisted constructors place their runtime argument first and also use `using:`.

## Isolation

Unprefixed bindings and `get` are MainActor-isolated by default. Services do not need to conform to `Sendable`.

```swift
@MainActor final class ScreenCoordinator {
    init(configuration: AppConfiguration) { }
}

let presentation = module {
    instance(AppConfiguration())
    single(ScreenCoordinator.self, using: ScreenCoordinator.init)
}

@MainActor func makeCoordinator() throws -> ScreenCoordinator {
    try get()
}
```

Use `nonisolatedSingle`, `nonisolatedFactory`, `nonisolatedScoped`, `nonisolatedInstance`, and `nonisolatedGet` for Sendable dependencies that must resolve outside MainActor. Use `actorSingle`, `actorFactory`, `actorScoped`, `actorInstance`, and async `actorGet` for an app-defined `GlobalActor`.
