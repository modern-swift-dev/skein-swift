# Applications, assisted factories, scopes, and disposal

[Documentation index](<doc:Skein>)

## Own an application

`SkeinApplication` is an independently owned container. Use it for tests, previews, or multiple compositions in one process. Its singleton cache and resolution state are isolated from every other application and from the global convenience API.

```swift
import Skein

final class APIClient { }

let application = try SkeinApplication {
    module {
        single(APIClient.self, using: APIClient.init)
    }
}

let client: APIClient = try application.get()
```

Validated construction uses binding-owned roots and `try await SkeinApplication(validation: .declaredRoots)`. The global startup APIs remain available for applications that deliberately use one process-wide composition.

## Typed assisted factories

Use an assisted factory when construction needs one runtime value. The argument type is part of the binding identity, so ordinary and multiple assisted factories for the same service and qualifier can coexist. Assisted bindings are factories and can only be resolved at a call site, not from another provider.

```swift
struct UserID: Hashable { let value: String }

final class UserPresenter {
    init(id: UserID) { }
}

let features = module {
    factory(UserPresenter.self, arguments: UserID.self, using: UserPresenter.init)
}

let application = try SkeinApplication { features }
let presenter: UserPresenter = try application.get(arguments: UserID(value: "42"))
```

The unprefixed factory and resolution APIs are MainActor-isolated. A closure-based assisted provider must spell `provider:` explicitly; a constructor-based assisted factory spells `using:`.

Initializer references include parameters that have Swift default values. Skein therefore treats those parameters as constructor dependencies. When a default should remain in effect, pass a forwarding closure that omits it instead of passing the initializer directly.

## Flat typed scopes

Declare a marker type, register `scoped` dependencies for it, then create a scope with a hashable, sendable ID. A scope inherits root bindings, shares root singletons, creates factories normally, and caches its scoped bindings until it closes. A scoped registration shadows a root binding with the same type and qualifier inside a matching scope.

```swift
struct UserScope: SkeinScope { }

final class UserSession { }

let definitions = module {
    scoped(UserSession.self, scope: UserScope.self, provider: { _ in UserSession() })
}

let application = try SkeinApplication { definitions }
let scope = try application.createScope(UserScope.self, id: "user-42")
let session: UserSession = try scope.get()
```

Only one active `(scope type, ID)` pair is allowed; closing it permits a replacement with the same ID. Scopes are flat: one scope cannot depend on bindings from another scope, and root bindings cannot depend on scoped bindings.

## Async disposal

`single` and `scoped` accept MainActor asynchronous `onClose` callbacks. Their `nonisolated...` and `actor...` counterparts retain the selected isolation. `close()` is async, idempotent, and disposes successfully created values once in reverse creation order.

```swift
final class Connection {
    func disconnect() async { }
}

let definitions = module {
    single(Connection.self, onClose: { connection in
        await connection.disconnect()
    }, provider: { _ in Connection() })
}

let application = try SkeinApplication { definitions }
_ = try application.get(Connection.self)
await application.close()
```

`stopSkein()` retains its legacy detach-only behavior. Use `await stopSkeinAndClose()` when the global application must dispose cached resources deterministically.

SwiftUI view-hierarchy integration is documented in the separate `SkeinSwiftUI` documentation archive.
