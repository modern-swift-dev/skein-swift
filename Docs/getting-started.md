# Getting started

[Documentation index](README.md)

Add the package to your Xcode project or Swift Package Manager manifest, then depend on its `Skein` product:

```swift
.product(name: "Skein", package: "skein-swift")
```

Define a module. A binding declares the type consumers resolve, and its provider receives a `Resolver` for any dependencies it needs.

```swift
import Foundation
import Skein

protocol Clock {
    func now() -> Date
}

final class SystemClock: Clock {
    func now() -> Date { Date() }
}

final class GreetingService {
    private let clock: any Clock

    init(clock: any Clock) {
        self.clock = clock
    }
}

let appModule = module {
    single((any Clock).self, provider: { _ in SystemClock() })
    factory(GreetingService.self, using: GreetingService.init)
}
```

Start the global container before resolving services. Use the contextual type with `get()` when Swift can infer it, or supply the type explicitly.

```swift
try startSkein {
    appModule
}

let greetingService: GreetingService = try get()
let clock = try get((any Clock).self)

// Call during orderly application shutdown or test teardown.
stopSkein()
```

The unprefixed registration and resolution APIs are MainActor-isolated. `get`, `startSkein`, and binding providers can throw. See [lifecycle and errors](lifecycle-and-errors.md) for the errors to handle.
