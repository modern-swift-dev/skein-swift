# Changelog

## 1.1.0 (unreleased)

### Source-breaking changes

- Scoped bindings may now be declared as structural scope roots with `.root()` or `.root(.structural)`, so validated startup checks scoped dependency graphs ([ADR-0001](docs/adr/0001-scoped-bindings-as-structural-scope-roots.md)). This changes `SkeinError`:
  - **Added** `SkeinError.eagerScopedRoot(type:qualifier:)`, thrown at application construction for `.root(.eager)` on a scoped binding. Exhaustive `switch` statements over `SkeinError` must handle the new case.
  - **Removed** `SkeinError.scopedBindingCannotBeRoot(type:qualifier:)`. Code that matches this case no longer compiles; match `eagerScopedRoot` instead.
