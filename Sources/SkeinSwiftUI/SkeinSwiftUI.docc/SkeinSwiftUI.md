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

## Topics

### SwiftUI integration

- ``SkeinStateObject``
- ``SwiftUICore/View/skeinApplication(_:)``
