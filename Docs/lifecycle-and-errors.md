# Lifecycle and errors

[Documentation index](README.md)

Koin has one global container. Start it once, resolve dependencies, then stop it when the application or isolated test is finished.

```swift
final class FeatureService { }

try startKoin {
    modules(appModule, featureModule)
}

defer { stopKoin() }

let service: FeatureService = try get()
```

Calling `stopKoin()` while Koin is already stopped is harmless. Starting after a stop creates a fresh container, so lazily-created singletons are recreated on their next resolution.

## Koin errors

`startKoin` and `get` throw these `KoinError` cases where applicable:

| Error | Cause |
| --- | --- |
| `.notStarted` | A global `get` happened before startup. |
| `.alreadyStarted` | `startKoin` was called while a container is active. |
| `.duplicateBinding(type:qualifier:)` | More than one module registered the same type and qualifier. |
| `.missingBinding(type:qualifier:)` | No registration matches the requested type and qualifier. |
| `.circularDependency(path:)` | Providers recursively depend on an active resolution path. |
| `.resolvedTypeMismatch(expected:actual:)` | A provider result cannot be cast to its registered type. |

Handle expected setup and lookup failures directly:

```swift
do {
    let service: FeatureService = try get()
    print(service)
} catch KoinError.notStarted {
    // Start Koin during the application's composition phase.
} catch KoinError.missingBinding(let type, let qualifier) {
    print("No binding for \(type), qualifier: \(String(describing: qualifier))")
}
```

Errors thrown by your provider are passed through unchanged; Koin does not wrap them. A failed `single` provider is not cached, so a subsequent `get` retries it.

```swift
enum ConfigurationError: Error { case unavailable }

let configuration = module {
    single(String.self) { _ in
        throw ConfigurationError.unavailable
    }
}
```

Avoid dependency cycles by passing only the dependencies a type needs into its initializer. Koin reports the cycle but does not break it automatically.
