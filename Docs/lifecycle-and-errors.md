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

`isKoinStarted` is a thread-safe, read-only snapshot of whether a global container is currently installed. It is useful for an application-owned idempotent startup policy, but checking it and then starting is not one atomic operation. Serialize process startup yourself.

```swift
if !isKoinStarted {
    try startKoin { modules(appModule) }
}
```

`get` takes a container snapshot before resolution. Therefore an in-flight resolution may complete after another thread calls `stopKoin()`, while a later global lookup observes `.notStarted`. Do not use `stopKoin()` as cancellation for providers; coordinate application shutdown around active work.

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
| `.mainActorBindingRequiresMainActor(type:qualifier:)` | An ordinary `get` attempted to resolve a main-actor binding. |

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

## Explicit startup validation

Use the validating startup overload to resolve the application entry points you explicitly choose. A `DependencyProbe` stores a service type and optional qualifier without creating a public unsafe registration API.

```swift
@MainActor func startApplication() throws {
    try startKoin(validating: [
        DependencyProbe((any HTTPClient).self),
        DependencyProbe(FeatureService.self, qualifier: Environment.production)
    ]) {
        modules(appModule, featureModule)
    }
}
```

Validation constructs a candidate container, resolves probes in manifest order with `mainActorGet`, then publishes that same container only if every probe succeeds. It reports the first existing provider or `KoinError` failure (including missing bindings, cycles, duplicate bindings, and type mismatches). A failed candidate is never installed.

Validation is deliberately not eager: only manifest entries are resolved because providers can have side effects. Successfully validated singletons stay cached in the published container; factories run once for validation and again for later lookups. Side effects from earlier probes are not rolled back if a later probe fails. Keep logging and any fail-fast decision in your application, outside Koin.
