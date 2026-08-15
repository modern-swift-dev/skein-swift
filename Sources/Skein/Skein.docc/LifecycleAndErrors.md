# Lifecycle, validation, and errors

[Documentation index](<doc:Skein>)

The global API owns one optional default application. List modules directly in its builder:

```swift
try startSkein {
    appModule
    featureModule
}
defer { stopSkein() }

let service: FeatureService = try get()
```

`stopSkein()` detaches the application. Use `await stopSkeinAndClose()` when cached values and active scopes must be disposed. `isSkeinStarted` is a snapshot; `startSkeinIfNeeded` atomically installs only the first candidate and does not evaluate later builders.

## Declared roots and validated startup

Attach root policy to the binding that owns it. Structural roots validate constructor metadata without executing providers. Eager roots are structurally validated first, then resolved sequentially in declaration order.

```swift
let featureModule = module {
    single(APIClient.self, using: APIClient.init)
    factory(FeatureService.self, using: FeatureService.init)
        .root(.eager)
}

let application = try await SkeinApplication(validation: .declaredRoots) {
    featureModule
}
print(application.startupValidationReport?.opaqueBindings ?? [])
```

Validated global startup is also async and publishes nothing after a validation failure:

```swift
let installed = try await startSkeinIfNeeded(validation: .declaredRoots) {
    appModule
    featureModule
}
```

After global publication, `currentSkeinValidationReport` exposes the installed application's report under the lifecycle lock and returns `nil` after stop.

Opaque closure providers appear in the validation report but are not failures. Constructor registrations expose all parameter-pack edges. Scoped roots and eager assisted roots are rejected; structural assisted roots are allowed.

## Errors and diagnostics

Lifecycle failures are direct `SkeinError` values. Resolution failures are `SkeinResolutionError`, which contains the underlying error and source-aware path frames. Invalid compositions fail with typed configuration errors. Isolation mismatches identify the required and actual binding isolation.

Provider side effects are not rolled back if a later eager root fails. Eager singles remain cached; eager factories run during startup and again on later resolution.
