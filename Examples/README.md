# Runnable examples

Each target is intentionally small and demonstrates one integration pattern using Skein's public API.

| Example | What it demonstrates |
| --- | --- |
| `BasicUsage` | An owned `SkeinApplication`, lazy singletons, factories, nested resolution, and typed assisted factories |
| `ModularComposition` | Splitting bindings across modules and exposing an implementation as a protocol |
| `QualifiedBindings` | Registering and resolving multiple values of the same type |
| `ErrorHandling` | Inspecting `SkeinResolutionError`, recovering underlying provider errors, and retrying failed singletons |
| `MainActorValidation` | MainActor-first bindings, binding-owned eager roots, and async validated startup |
| `TestingExampleTests` | Replacing a production module with a hand-written fake and isolating test containers |

From this directory, run an executable with:

```sh
swift run BasicUsage
swift run ModularComposition
swift run QualifiedBindings
swift run ErrorHandling
swift run MainActorValidation
```

Run the testing example with:

```sh
swift test
```

The examples use a local package dependency (`.package(path: "..")`), so edits to Skein are reflected immediately.
