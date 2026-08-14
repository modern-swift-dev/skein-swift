# Lifecycle, validation, and errors

[Documentation index](README.md)

The legacy global API manages one optional default application. Start it once, resolve dependencies, then stop it during application or test teardown. For independently owned containers, use `SkeinApplication`; see [applications, assisted factories, scopes, and disposal](ergonomics.md).

```swift
final class FeatureService { }

try startSkein {
    modules(appModule, featureModule)
}
defer { stopSkein() }

let service: FeatureService = try get()
```

Calling `stopSkein()` while stopped is harmless. It detaches the default application without disposing cached instances. Use `await stopSkeinAndClose()` when global singletons and active scopes need deterministic async disposal.

`isSkeinStarted` is a thread-safe snapshot. For atomic idempotent startup, use `startSkeinIfNeeded`; it returns `true` only for the caller that installed the default application.

```swift
if try startSkeinIfNeeded({ modules(appModule) }) {
    // This caller installed the default application.
}
```

## Errors and diagnostics

Global lifecycle failures stay direct `SkeinError` values: `.notStarted` and `.alreadyStarted`. Failures that occur while resolving a binding are `SkeinResolutionError` values. Its `underlying` retains the original `SkeinError` or provider-specific error, and `path` contains the full root-to-failure trace with registration locations where known.

```swift
do {
    let service: FeatureService = try get()
    print(service)
} catch SkeinError.notStarted {
    // Start Skein during the application's composition phase.
} catch let error as SkeinResolutionError {
    if case let SkeinError.missingBinding(type, qualifier) = error.underlying {
        print("No binding for \(type), qualifier: \(String(describing: qualifier))")
    }
}
```

Provider errors are therefore still recoverable by casting `error.underlying`. A failed `single` provider is not cached, so a later resolution retries it. Duplicate registrations during application creation throw `SkeinConfigurationError`, which contains its `SkeinError.duplicateBinding` cause and both registration locations.

## Runtime startup probes

Use the validating startup overload to resolve the application entry points you explicitly choose. A `DependencyProbe` stores a service type and optional qualifier without exposing an unsafe registration API.

```swift
@MainActor func startApplication() throws {
    try startSkein(validating: [
        DependencyProbe((any HTTPClient).self),
        DependencyProbe(FeatureService.self, qualifier: Environment.production)
    ]) {
        modules(appModule, featureModule)
    }
}
```

Validation constructs a candidate application, resolves probes in manifest order with `mainActorGet`, then publishes that application only if all probes succeed. Successfully probed singletons stay cached; factories run once for validation and again for later lookups. Provider side effects are not rolled back after a later probe fails.

## Structural graph validation

For constructor registrations, declare the roots you want to inspect and call `validateGraph()`. This checks statically known constructor edges without executing providers. It detects missing bindings, known cycles, actor violations, and invalid scope lifetimes. Reached closure registrations are reported as `opaqueBindings`; use `DependencyProbe` when runtime validation must cross that boundary.

```swift
final class APIClient { }
final class FeatureService {
    init(client: APIClient) { }
}

let definitions = module {
    single(APIClient.self, using: APIClient.init)
    factory(FeatureService.self, using: FeatureService.init)
}.validating(FeatureService.self)

let application = try SkeinApplication { modules(definitions) }
let report = try application.validateGraph()
print(report.opaqueBindings)
```
