# Skein

Skein is a type-safe dependency-injection container for Swift applications. It gathers an application's dependency graph into one explicit, inspectable composition.

## Language

### Composition

**Application**:
An independently owned container of bindings, their cached values, and the scopes created from it.
_Avoid_: Container (internal type), app

**Process-wide application**:
The single application installed for global resolution by starting Skein.
_Avoid_: Global container, shared instance

**Module**:
A named group of bindings that an application is composed from.

**Binding**:
A declaration that tells an application how to produce a service of a given type, with a lifetime and an isolation.
_Avoid_: Registration, provider

**Qualifier**:
A value that distinguishes two bindings of the same service type.
_Avoid_: Name, tag

**Assisted arguments**:
Values supplied by the caller at resolution time and passed to a binding alongside its resolved dependencies.

### Lifetimes

**Single**:
A lifetime whose service is created once per application, on first use.
_Avoid_: Singleton

**Factory**:
A lifetime whose service is created anew for every resolution.

**Scoped**:
A lifetime whose service is created once per scope.

**Scope kind**:
The type that identifies a family of scopes and selects which scoped bindings apply to them.

**Scope**:
A live instance of a scope kind, created from an application with a stable identity, that caches its scoped services until it is closed.
_Avoid_: Scope instance

**Seed**:
An existing service placed into a scope at creation instead of producing it from its binding.

### Validation

**Declared root**:
A binding explicitly marked as an entry point of the graph, from which startup validation walks dependencies.
_Avoid_: Entry point

**Scope root**:
A declared root on a scoped binding, validated from the point of view of its scope kind.

**Structural root**:
A declared root whose graph is checked without creating any service.

**Eager root**:
A declared root whose service is also created during validated startup. Only single and factory bindings may be eager roots.

**Opaque binding**:
A binding whose dependencies cannot be known without running it, and which validation therefore reports instead of traversing.

### Isolation

**Isolation**:
The concurrency domain a binding's service is created on: the main actor, nonisolated, or a custom global actor.

### Lifecycle

**Stop**:
Uninstalling the process-wide application so it no longer serves global resolution.
_Avoid_: Shutdown

**Close**:
Ending an application's or scope's lifetime and disposing its cached services in reverse creation order.
_Avoid_: Shutdown, teardown, dispose (as the lifecycle verb)

**Disposer**:
The callback a binding provides to release a cached service when its owner closes.
_Avoid_: Finalizer, cleanup handler
