# Runnable examples

Each target is intentionally small and demonstrates one integration pattern using only Koin's current API.

| Example | What it demonstrates |
| --- | --- |
| `BasicUsage` | Starting Koin, lazy singletons, factories, nested resolution, and shutdown |
| `ModularComposition` | Splitting bindings across modules and exposing an implementation as a protocol |
| `QualifiedBindings` | Registering and resolving multiple values of the same type |
| `ErrorHandling` | Inspecting `KoinError`, propagating provider errors, and retrying failed singletons |
| `TestingExampleTests` | Replacing a production module with a hand-written fake and isolating test containers |

From this directory, run an executable with:

```sh
swift run BasicUsage
swift run ModularComposition
swift run QualifiedBindings
swift run ErrorHandling
```

Run the testing example with:

```sh
swift test
```

The examples use a local package dependency (`.package(path: "..")`), so edits to Koin are reflected immediately.
