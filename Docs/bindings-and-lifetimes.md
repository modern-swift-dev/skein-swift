# Bindings and lifetimes

[Documentation index](README.md)

Every registration is either a `single` or a `factory`.

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

There is no scoped lifetime in the current API. Stop and restart the global container when you need an entirely fresh set of singleton instances.
