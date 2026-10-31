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

## Retained results and retries

A resolving wrapper keeps its first result for the lifetime of the view's identity. Changing the environment application, qualifier, or arguments later does not resolve again; give the view a new identity with `.id(...)` to force a fresh resolution.

One failure is retried: if the wrapper first updates before any application is in the environment, it holds ``SkeinSwiftUIError/missingApplication`` only until a later update finds an application, and then resolves from it. Successful results and provider failures stay retained, so a failing provider does not run again on every render. `.instance(model)` wrappers never resolve and are unaffected.

## Topics

### SwiftUI integration

- ``SkeinStateObject``
- ``SwiftUICore/View/skeinApplication(_:)``
