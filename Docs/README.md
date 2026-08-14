# Skein documentation

Skein is a small, type-safe dependency-injection container for Swift. It supports independently owned applications as well as a global convenience API. The `SkeinSwiftUI` product is documented below.

## Guides

- [Getting started](getting-started.md) — install, define a module, start Skein, and resolve a service.
- [Bindings and lifetimes](bindings-and-lifetimes.md) — choose between singleton and factory lifetimes, including main-actor bindings.
- [Modules and protocol bindings](modules-and-protocol-bindings.md) — split registrations by feature and expose implementations as protocols.
- [Qualifiers](qualifiers.md) — register more than one binding for a type.
- [Applications, assisted factories, scopes, and disposal](ergonomics.md) — own a container, supply runtime arguments, and manage a scoped lifetime.
- [Lifecycle and errors](lifecycle-and-errors.md) — startup, shutdown, validation, and failure behaviour.
- [MainActor-first and validation migration](migration-main-actor-validation.md) — binding roots and breaking API renames.
- [Testing with manual doubles](testing.md) — isolate tests with a fresh container and hand-written fakes.
- [Concurrency and main-actor bindings](concurrency-and-limitations.md) — actor-isolated resolution, thread-safety guarantees, and current boundaries.

For complete programs rather than isolated snippets, see the [runnable examples](../Examples/README.md).

## API at a glance

| Need | API |
| --- | --- |
| Create registrations | `module { ... }` |
| Share one lazy instance | `single(Service.self, using: Service.init)` |
| Create on every lookup | `factory(Service.self, using: Service.init)` |
| Create with a typed runtime argument | `factory(Service.self, arguments: Input.self, provider: { _, input in ... })` |
| Cache once per scope | `scoped(Service.self, scope: FeatureScope.self, provider: { ... })` |
| Register a supplied value | `instance(value)` |
| Opt into Sendable nonisolated access | `nonisolatedSingle` / `nonisolatedFactory` / `nonisolatedGet` |
| Use a custom global actor | `actorSingle(..., isolatedTo: Actor.self)` / `await actorGet()` |
| Combine modules | List modules directly in the application builder |
| Start / validate / stop globally | `startSkein { ... }` / `await startSkein(validation: .declaredRoots) { ... }` / `stopSkein()` |
| Create an isolated application | `try SkeinApplication { module }` |
| Resolve a service | `try get()` or `try get(Service.self)` |
| Resolve inside a provider | `try resolver.get()` |
| Resolve a MainActor service | `try get()` / `try resolver.get()` |
| Inspect lifecycle state | `isSkeinStarted` |
| Declare and validate a graph root | `factory(...).root()` and `await SkeinApplication(validation: .declaredRoots) { ... }` |
| Distinguish equal service types | `qualifier: SomeQualifier.value` |
