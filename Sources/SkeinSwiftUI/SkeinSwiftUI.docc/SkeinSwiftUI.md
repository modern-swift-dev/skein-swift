# ``SkeinSwiftUI``

Use Skein services in SwiftUI view hierarchies.

## Overview

Add the separate `SkeinSwiftUI` product, then supply an application explicitly to a view hierarchy. There is no global fallback, and nested values follow SwiftUI's nearest-value-wins behavior.

```swift
import SkeinSwiftUI
import SwiftUI

@MainActor final class AccountModel: ObservableObject { }

struct AccountView: View {
    @SkeinStateObject<AccountModel> private var model: AccountModel?

    init() {
        _model = .resolving()
    }

    init(model: AccountModel) {
        _model = .instance(model)
    }

    var body: some View {
        if let model { Text(String(describing: model)) }
        else { Text("Could not create account") }
    }
}

let application = try! SkeinApplication {
    module { factory(AccountModel.self, using: AccountModel.init) }
}

AccountView().skeinApplication(application)
```

`SkeinStateObject.resolving(arguments:qualifier:)` supports assisted factories. `.instance(model)` works without an environment application and preserves identity. The wrapper retains either the object or failure; its projected value is `Result<Model, Error>?`.

## Observation models

For models built with the Observation framework, use ``SkeinState`` instead. It has the same `.resolving()`, `.resolving(qualifier:)`, `.resolving(arguments:qualifier:)` and `.instance(_:)` options and the same `Result<Model, Error>?` projected value. SwiftUI tracks the model properties the view reads, so the view re-renders when they change.

```swift
import Observation

@Observable @MainActor final class CounterModel {
    var count = 0
}

struct CounterView: View {
    @SkeinState<CounterModel> private var model: CounterModel?

    init() {
        _model = .resolving()
    }

    var body: some View {
        if let model { Text("\(model.count)") }
    }
}
```

## View-owned scopes

Use `.skeinScope(_:id:)` to give a view a scope that lives as long as the view's SwiftUI identity. The scope is created from the environment's application, and descendants resolve from it explicitly with `.resolving(in:)`, which both wrappers support. Wrappers without `in:` keep resolving from the application, so adding a scope never changes what unrelated descendants resolve.

```swift
enum SessionScope: SkeinScope { }

struct SessionView: View {
    let user: User

    var body: some View {
        SessionDetails()
            .skeinScope(SessionScope.self, id: user.id)
    }
}

struct SessionDetails: View {
    @SkeinStateObject<SessionModel> private var model: SessionModel?

    init() {
        _model = .resolving(in: SessionScope.self)
    }

    var body: some View { /* ... */ }
}
```

- The scope is created on the first update that finds an application, and stays open across re-renders, tab switches and navigation pushes. It begins closing when the owning view's identity ends, and its disposers run asynchronously.
- Use `.skeinScope(_:id:seeding:as:qualifier:)` to place an existing service in the scope when it is created. The seed is captured once.
- Each view owns its own scope: view-owned scopes never conflict with each other or with scopes created directly from the application, even with the same kind and ID. If the `id` changes while the view keeps its identity, the original scope is kept; use `.id(...)` to replace it.
- Nested `.skeinScope` modifiers of the same kind follow nearest-value-wins behavior.
- A wrapper resolving `in:` a kind with no surrounding modifier fails with ``SkeinSwiftUIError/missingScope(scope:)``, which is retried once the scope appears. If creating the scope throws, the wrapper fails with ``SkeinSwiftUIError/scopeCreationFailed(scope:underlying:)``, which is kept until `.id(...)` gives the view a new identity.

## Retained results and retries

Both wrappers follow the same rules. A resolving wrapper keeps its first result for the lifetime of the view's identity. Changing the environment application, qualifier, or arguments later does not resolve again; give the view a new identity with `.id(...)` to force a fresh resolution.

Two failures mean "not there yet" and are retried: ``SkeinSwiftUIError/missingApplication`` and ``SkeinSwiftUIError/missingScope(scope:)``. The wrapper holds them only until a later update finds the application or scope, and then resolves from it. Successful results and provider failures stay retained, so a failing provider does not run again on every render. `.instance(model)` wrappers never resolve and are unaffected.

## Topics

### SwiftUI integration

- ``SkeinStateObject``
- ``SkeinState``
- ``SwiftUICore/View/skeinScope(_:id:)``
- ``SwiftUICore/View/skeinScope(_:id:seeding:as:qualifier:)``
- ``SkeinSwiftUIError``
- ``SwiftUICore/View/skeinApplication(_:)``
