# Modules and protocol bindings

[Documentation index](<doc:Skein>)

Modules keep registrations close to the feature that owns them. Application builders accept individual modules, arrays, optionals, conditions, and loops directly.

```swift
import Skein

protocol HTTPClient {
    func get(path: String) throws -> String
}

final class URLSessionClient: HTTPClient {
    func get(path: String) throws -> String { "response" }
}

final class ArticleRepository {
    private let client: any HTTPClient

    init(client: any HTTPClient) {
        self.client = client
    }
}

let networking = module {
    single((any HTTPClient).self, provider: { _ in URLSessionClient() })
}

let articles = module {
    factory(ArticleRepository.self, using: ArticleRepository.init)
}

try startSkein {
    networking
    articles
}
```

The binding key is the declared type, not the concrete type returned by the provider. Register a protocol existential such as `(any HTTPClient).self` when consumers depend on the protocol. Resolve the same declared type inside providers and at call sites.

```swift
let client = try get((any HTTPClient).self)
let repository: ArticleRepository = try get()
```

All modules are collected during application creation. Registering the same type and qualifier twice, whether in one module or separate modules, fails creation with a source-aware `SkeinConfigurationError` whose `underlying` is `SkeinError.duplicateBinding`. Use <doc:Qualifiers> when multiple implementations of one type are intentional.

## Test or environment overlays

`overriding(_:)` creates a reusable module where registrations in the overlay replace exact binding keys from the base module. Duplicates within either input module still fail when an application is created.

```swift
let production = module {
    single((any HTTPClient).self, provider: { _ in URLSessionClient() })
}
final class PreviewHTTPClient: HTTPClient {
    func get(path: String) throws -> String { "preview" }
}
let preview = module {
    single((any HTTPClient).self, provider: { _ in PreviewHTTPClient() })
}

let previewApplication = try SkeinApplication {
    production.overriding(preview)
}
```
