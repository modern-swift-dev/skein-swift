# Changelog

## 1.1.0 (unreleased)

### Source-breaking changes

- Scoped bindings may now be declared as structural scope roots with `.root()` or `.root(.structural)`, so validated startup checks scoped dependency graphs ([ADR-0001](docs/adr/0001-scoped-bindings-as-structural-scope-roots.md)). This changes `SkeinError`:
  - **Added** `SkeinError.eagerScopedRoot(type:qualifier:)`, thrown at application construction for `.root(.eager)` on a scoped binding. Exhaustive `switch` statements over `SkeinError` must handle the new case.
  - **Removed** `SkeinError.scopedBindingCannotBeRoot(type:qualifier:)`. Code that matches this case no longer compiles; match `eagerScopedRoot` instead.

### Additions

- `SkeinApplication.createScope(_:id:seeding:as:qualifier:)` keys a seed by an explicit service type and optional qualifier, so an existential such as `any Session` can seed a protocol-typed scoped binding, and qualified scoped bindings can be seeded.
- Constructor registrations for scoped bindings: `scoped`, `nonisolatedScoped`, and `actorScoped` accept `using:` in both argument orders. They record their dependency edges, so a scope root registered this way is fully validated at startup.

### Deprecations

- `SkeinApplication.createScope(_:id:seeding:)` is deprecated in favour of `createScope(_:id:seeding:as:qualifier:)`. Its behaviour is unchanged: the seed is keyed by the argument's static type.

### Behaviour changes

- A cancelled `actorGet` waiter on a shared custom-actor single or scoped creation now throws a bare `CancellationError` immediately instead of waiting for the creation to finish. More generally, `actorGet` no longer wraps a `CancellationError` in `SkeinResolutionError` when the calling task is cancelled. The shared creation keeps running for other waiters.
- `SkeinStateObject` forwards a model's `objectWillChange` synchronously when the model publishes on the main thread, so SwiftUI sees the change before the mutation and keeps transaction and animation context. Models that publish from other threads are still forwarded on the main queue.
- `SkeinStateObject` now retries a `SkeinSwiftUIError.missingApplication` failure once an application appears in the environment. Successful results and provider failures are still kept for the view's identity.
- A scope frees its `(kind, ID)` slot as soon as it begins closing, so a replacement with the same kind and ID can be created while the previous scope is still disposing, instead of throwing `duplicateScope`. Closing the application still waits for scopes that are mid-close.

### Fixes

- Validated global startup now closes the candidate application, running its eager roots' disposers, when the startup is cancelled or superseded before it is published.
