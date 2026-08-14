# Applications, assisted factories, scopes, and disposal

[Documentation index](README.md)

## Own an application

`SkeinApplication` is an independently owned container. Use it for tests, previews, or multiple compositions in one process. Its singleton cache and resolution state are isolated from every other application and from the legacy global API.

```swift
import Skein

final class APIClient { }

let application = try SkeinApplication {
    modules(module {
        single(APIClient.self, using: APIClient.init)
    })
}

let client: APIClient = try application.get()
```

`SkeinApplication(validating:_:)` accepts a `[DependencyProbe]` on the main actor and validates those runtime roots before the application is returned. The global `startSkein` APIs remain available for applications that deliberately use one process-wide composition.

## Typed assisted factories

Use an assisted factory when construction needs one runtime value. The argument type is part of the binding identity, so ordinary and multiple assisted factories for the same service and qualifier can coexist. Assisted bindings are factories and can only be resolved at a call site, not from another provider.

```swift
struct UserID: Hashable { let value: String }

final class UserPresenter {
    init(id: UserID) { }
}

let features = module {
    factory(UserPresenter.self, arguments: UserID.self) { _, id in
        UserPresenter(id: id)
    }
}

let application = try SkeinApplication { modules(features) }
let presenter: UserPresenter = try application.get(arguments: UserID(value: "42"))
```

Use `mainActorFactory(_:arguments:qualifier:provider:)` and `mainActorGet(arguments:qualifier:)` for main-actor assisted services.

## Flat typed scopes

Declare a marker type, register `scoped` dependencies for it, then create a scope with a hashable, sendable ID. A scope inherits root bindings, shares root singletons, creates factories normally, and caches its scoped bindings until it closes. A scoped registration shadows a root binding with the same type and qualifier inside a matching scope.

```swift
struct UserScope: SkeinScope { }

final class UserSession { }

let definitions = module {
    scoped(UserSession.self, scope: UserScope.self) { _ in UserSession() }
}

let application = try SkeinApplication { modules(definitions) }
let scope = try application.createScope(UserScope.self, id: "user-42")
let session: UserSession = try scope.get()
```

Only one active `(scope type, ID)` pair is allowed; closing it permits a replacement with the same ID. Scopes are flat: one scope cannot depend on bindings from another scope, and root bindings cannot depend on scoped bindings.

## Async disposal

`single` and `scoped` accept optional asynchronous `onClose` callbacks. `mainActorSingle` and `mainActorScoped` accept main-actor callbacks. `close()` is async, idempotent, and disposes successfully created values once in reverse creation order. Closing an application closes active scopes first, then its root singletons.

```swift
final class Connection {
    func disconnect() async { }
}

let definitions = module {
    single(Connection.self, onClose: { connection in
        await connection.disconnect()
    }) { _ in Connection() }
}

let application = try SkeinApplication { modules(definitions) }
_ = try application.get(Connection.self)
await application.close()
```

`stopSkein()` retains its legacy detach-only behavior. Use `await stopSkeinAndClose()` when the global application must dispose cached resources deterministically.

## SwiftUI

Add the separate `SkeinSwiftUI` product, then supply an application explicitly to a view hierarchy. There is no global fallback, and nested values follow SwiftUI's nearest-value-wins behavior.

```swift
import SkeinSwiftUI
import SwiftUI

@MainActor final class AccountModel: ObservableObject { }

struct AccountView: View {
    @SkeinStateObject<AccountModel> private var model: AccountModel?

    var body: some View {
        if let model { Text(String(describing: model)) }
        else { Text("Could not create account") }
    }
}

let application = try! SkeinApplication {
    modules(module { mainActorFactory(AccountModel.self) { _ in AccountModel() } })
}

AccountView().skeinApplication(application)
```

`SkeinStateObject` retains either the resolved object or its failure for its SwiftUI identity. Its projected value exposes `Result<Model, Error>?`; no supplied application produces `SkeinSwiftUIError.missingApplication`. To retry after changing the application or assisted arguments, change the view identity with `.id(...)`. The adapter is available on iOS/tvOS 17, macOS 14, watchOS 10, and visionOS 1.
