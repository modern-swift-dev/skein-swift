# MainActor-first and validation migration

[Documentation index](README.md)

Skein's canonical API is now MainActor-isolated. Rename former MainActor-prefixed calls to their unprefixed forms:

```swift
let uiModule = module {
    single(AppPresenter.self, using: AppPresenter.init)
}

@MainActor func showUI() throws {
    let presenter: AppPresenter = try get()
    _ = presenter
}
```

Former unprefixed concurrent bindings become `nonisolatedSingle`, `nonisolatedFactory`, or `nonisolatedScoped`, and resolve through `nonisolatedGet`. These APIs require Sendable values and closures. App-defined global actors use `actor...(..., isolatedTo:)` and async `actorGet`.

## Replace validation manifests with binding roots

Declare each startup root once on its registration. `.structural` inspects known constructor edges without running the provider; `.eager` adds sequential startup resolution after all structural checks pass.

```swift
let uiModule = module {
    factory(AppPresenter.self, using: AppPresenter.init)
        .root(.eager)
}

@MainActor func startDependencies() async throws {
    _ = try await startSkeinIfNeeded(validation: .declaredRoots) {
        coreModule
        uiModule
    }
}
```

The startup report retains opaque closure bindings as diagnostics. Eager singletons remain cached; eager factories run again on later lookup. Earlier provider side effects are not rolled back after a later failure.

## Other breaking renames

- List modules directly in application builders; arrays, optionals, branches, and loops compose naturally.
- Use `instance(value)` for supplied configuration values.
- Use `using:` for constructor injection at any arity and for assisted constructors whose runtime argument is first.
- Spell closure-based assisted registrations with `provider:` to distinguish them from constructor packs.
- Use `SkeinStateObject.resolving(...)` or `.instance(model)` in SwiftUI.
