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

Attach root policy to the binding that owns it. Validated startup walks the dependency graph from every *declared root*:

- A *structural root* (`.root()` or `.root(.structural)`) is checked from constructor metadata without creating any service.
- An *eager root* (`.root(.eager)`) is structurally validated first, then resolved sequentially in declaration order. Only single and factory bindings may be eager roots.
- A *scope root* is a structural root on a scoped binding. It is validated from the point of view of its scope kind: its dependencies resolve to scoped bindings of the same kind first, then to single and factory bindings, as they do at runtime.

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

Opaque closure providers appear in the validation report but are not failures. Constructor registrations expose all parameter-pack edges. Structural assisted roots are allowed; eager assisted roots are rejected with `SkeinError.eagerAssistedRoot`.

### Scope roots

Mark a scoped binding as a structural root to validate its graph at startup. No provider runs, and the scope root is reported like any other root.

```swift
let sessionModule = module {
    scoped(SessionScope.self, SessionModel.self) { resolver in
        SessionModel(api: try resolver.get())
    }
    .root()
}
```

Where dependency edges are known, a missing dependency fails with `GraphValidationError.missingBinding`, a dependency on another scope kind's binding fails with `crossScopeDependency`, and an isolation violation fails with `isolationMismatch`. Scoped registrations take closure providers, which are opaque: the scope root above appears in `opaqueBindings`, and its dependencies are not traversed.

Scope roots cannot be eager, because no scope exists at startup: `.root(.eager)` on a scoped binding makes application construction throw `SkeinError.eagerScopedRoot`. A single or factory root that depends on a scoped binding still fails with `GraphValidationError.rootDependsOnScopedBinding`.

## Errors and diagnostics

Lifecycle failures are direct `SkeinError` values. Resolution failures are `SkeinResolutionError`, which contains the underlying error and source-aware path frames. Invalid compositions fail with typed configuration errors. Isolation mismatches identify the required and actual binding isolation.

If eager startup fails or is cancelled, initialization awaits disposal of successfully cached services before throwing. Provider side effects outside managed singleton and scope resources are not rolled back. After successful startup, eager singles remain cached; eager factories run during startup and again on later resolution.
