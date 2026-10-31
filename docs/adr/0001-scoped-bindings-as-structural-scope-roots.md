---
status: accepted
---

# Scoped bindings may be structural scope roots

Startup validation only walks declared roots, and scoped bindings were forbidden from being roots. As a result, scoped dependency graphs were never validated at all, and the cross-scope and scoped-parent checks could never run. We now allow `.root(.structural)` on scoped bindings, validated from the point of view of their scope kind. Eager scope roots stay rejected because no scope exists at startup.

## Consequences

Eager scope roots raise a new `SkeinError.eagerScopedRoot`. `scopedBindingCannotBeRoot` is removed. Both changes ship in 1.1.0 as a documented source break rather than waiting for a major version.

## Considered Options

- **Validate every scoped binding automatically under `.declaredRoots`**: rejected because it changes behavior. Applications that start successfully today could start failing.
- **A new `ValidationPolicy` case that walks all scoped bindings**: rejected in favor of keeping validation opt-in, binding by binding, which matches how declared roots already work.
