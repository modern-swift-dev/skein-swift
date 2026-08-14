# Qualifiers

[Documentation index](README.md)

Use a qualifier when one service type has more than one intentional binding. A qualifier must conform to `SkeinQualifier`, which requires `Hashable` and `Sendable`. An enum is a concise, type-safe choice.

```swift
import Foundation
import Skein

protocol APIEndpoint {
    var baseURL: URL { get }
}

struct Endpoint: APIEndpoint {
    let baseURL: URL
}

enum EndpointKind: SkeinQualifier {
    case production
    case staging
}

let endpoints = module {
    single((any APIEndpoint).self, qualifier: EndpointKind.production) { _ in
        Endpoint(baseURL: URL(string: "https://api.example.com")!)
    }
    single((any APIEndpoint).self, qualifier: EndpointKind.staging) { _ in
        Endpoint(baseURL: URL(string: "https://staging.example.com")!)
    }
}

try startSkein { modules(endpoints) }

let production = try get(
    (any APIEndpoint).self,
    qualifier: EndpointKind.production
)
```

An unqualified lookup is distinct from every qualified lookup. If only qualified bindings exist, `try get((any APIEndpoint).self)` throws `SkeinResolutionError` whose `underlying` error is `SkeinError.missingBinding`.

Qualifier identity includes both its concrete type and its value. Two different qualifier types with equal-looking cases do not collide:

```swift
enum PrimaryEndpoint: SkeinQualifier { case active }
enum SecondaryEndpoint: SkeinQualifier { case active }
```

Use the exact same qualifier type and value at registration and resolution. Each qualified `single` maintains its own cached instance.
