# Bindings and lifetimes

[Documentation index](README.md)

Root registrations are either a `single` or a `factory`. A `scoped` registration is cached once per active typed scope; see [applications, assisted factories, scopes, and disposal](ergonomics.md).

| Binding | Provider runs | Result |
| --- | --- | --- |
| `single` | At the first successful resolution | The same instance/value is returned for later resolutions. |
| `factory` | At every resolution | A new value is returned each time. |

```swift
import Foundation
import Koin

final class SessionStore { }

final class RequestID {
    let value = UUID()
}

let module = module {
    single(SessionStore.self) { _ in SessionStore() }
    factory(RequestID.self) { _ in RequestID() }
}

try startKoin { modules(module) }

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
    single(APIClient.self) { _ in APIClient() }
    factory(ProfileLoader.self) { resolver in
        ProfileLoader(client: try resolver.get())
    }
}
```

## Constructor registrations

When a type can be constructed entirely from unqualified dependencies, use `using:`. Koin supports constructors with zero through four dependencies, resolves their declared parameter types, and records those edges for structural validation.

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

The exposed service type may be a protocol existential. Use a closure registration for qualified dependencies, assisted construction, or constructors with more than four dependencies.

## Main-actor bindings

Use `mainActorSingle` and `mainActorFactory` for services that are isolated to the main actor, such as UI coordinators and view models. Their providers are `@MainActor`, and they must be resolved with `mainActorGet` from main-actor code.

```swift
@MainActor final class ScreenCoordinator {
    init(configuration: AppConfiguration) { }
}

let presentation = module {
    single(AppConfiguration.self) { _ in AppConfiguration() }
    mainActorSingle(ScreenCoordinator.self) { resolver in
        ScreenCoordinator(configuration: try resolver.get())
    }
}

@MainActor func makeCoordinator() throws -> ScreenCoordinator {
    try mainActorGet()
}
```

`mainActorSingle` has the same lazy, shared-instance lifetime as `single`; `mainActorFactory` creates a new value for every `mainActorGet`. Services do not need to conform to `Sendable`.

An ordinary `get` never resolves a main-actor binding, even if a singleton has already been created. It throws `.mainActorBindingRequiresMainActor(type:qualifier:)`. If a provider needs a main-actor service directly or transitively, register that provider with `mainActorSingle` or `mainActorFactory` and use `resolver.mainActorGet(...)`.
