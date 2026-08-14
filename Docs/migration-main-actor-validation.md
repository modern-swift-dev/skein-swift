# Graph validation and migration

[Documentation index](README.md)

Koin now owns the framework-level work that application wrappers commonly provided: main-actor binding isolation, an inspectable lifecycle snapshot, and explicit dependency probes during startup. Applications still own their composition policy, logging, and whether an error should terminate startup.

## Replace main-actor wrappers

Before, an application wrapper commonly erased isolation to make a UI service fit an ordinary provider:

```swift
// Remove this application-specific bridge.
// final class UnsafePresenterBox: @unchecked Sendable { ... }
// MainActor.assumeIsolated { presenter }
```

Register and resolve the service directly instead:

```swift
let uiModule = module {
    mainActorSingle(AppPresenter.self) { _ in AppPresenter() }
}

@MainActor func showUI() throws {
    let presenter: AppPresenter = try mainActorGet()
    _ = presenter
}
```

This makes actor isolation visible to the compiler and preserves support for non-`Sendable` service types.

## Replace lifecycle flags and startup probes

Replace a wrapper-maintained `didStart` flag with `isKoinStarted` when a read-only snapshot is enough. When the desired policy is "install only if absent", use `startKoinIfNeeded`, which atomically publishes one default application and returns whether this caller installed it.

Replace custom eager-resolution loops with an explicit `DependencyProbe` manifest:

```swift
@MainActor func startDependencies() throws {
    guard !isKoinStarted else { return }

    try startKoin(validating: [
        DependencyProbe(AppPresenter.self),
        DependencyProbe((any AccountRepository).self, qualifier: Environment.production)
    ]) {
        modules(coreModule, uiModule)
    }
}
```

The manifest is intentionally selective. Koin does not instantiate every registered binding because providers may create connections, start work, or otherwise have side effects. Validation stops at the first error; successful singleton probes remain cached, factories run again when subsequently resolved, and side effects are not rolled back after failure.

Wrap the call above in your application's logging and fail-fast policy if needed. Koin reports errors but does not log, terminate the process, or choose a recovery strategy.
