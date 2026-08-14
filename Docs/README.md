# Koin documentation

Koin is a small, type-safe dependency-injection container for Swift. It supports independently owned applications as well as the legacy global convenience API. The `KoinSwiftUI` product is documented below.

## Guides

- [Getting started](getting-started.md) — install, define a module, start Koin, and resolve a service.
- [Bindings and lifetimes](bindings-and-lifetimes.md) — choose between singleton and factory lifetimes, including main-actor bindings.
- [Modules and protocol bindings](modules-and-protocol-bindings.md) — split registrations by feature and expose implementations as protocols.
- [Qualifiers](qualifiers.md) — register more than one binding for a type.
- [Applications, assisted factories, scopes, and disposal](ergonomics.md) — own a container, supply runtime arguments, and manage a scoped lifetime.
- [Lifecycle and errors](lifecycle-and-errors.md) — startup, shutdown, validation, and failure behaviour.
- [Graph validation and migration](migration-main-actor-validation.md) — explicit startup manifests and replacing application wrappers.
- [Testing with manual doubles](testing.md) — isolate tests with a fresh container and hand-written fakes.
- [Concurrency and main-actor bindings](concurrency-and-limitations.md) — actor-isolated resolution, thread-safety guarantees, and current boundaries.

For complete programs rather than isolated snippets, see the [runnable examples](../Examples/README.md).

## API at a glance

| Need | API |
| --- | --- |
| Create registrations | `module { ... }` |
| Share one lazy instance | `single(Service.self) { ... }` |
| Create on every lookup | `factory(Service.self) { ... }` |
| Create with a typed runtime argument | `factory(Service.self, arguments: Input.self) { _, input in ... }` |
| Cache once per scope | `scoped(Service.self, scope: FeatureScope.self) { ... }` |
| Share one main-actor instance | `mainActorSingle(Service.self) { ... }` |
| Create on every main-actor lookup | `mainActorFactory(Service.self) { ... }` |
| Combine modules | `modules(networking, feature)` |
| Start / validate / stop the global container | `startKoin { ... }` / `startKoin(validating: ...) { ... }` / `stopKoin()` |
| Create an isolated application | `try KoinApplication { modules(...) }` |
| Resolve a service | `try get()` or `try get(Service.self)` |
| Resolve inside a provider | `try resolver.get()` |
| Resolve a main-actor service | `try mainActorGet()` / `try resolver.mainActorGet()` |
| Inspect lifecycle state | `isKoinStarted` |
| Validate selected graph entry points | `DependencyProbe(Service.self)` |
| Validate constructor edges without constructing values | `try application.validateGraph()` with `.validating(Service.self)` |
| Distinguish equal service types | `qualifier: SomeQualifier.value` |
