# Repository Guidelines

## Structure

- Keep core code in `Sources/Skein`; isolate SwiftUI and Vapor code in their dedicated targets and matching test targets.
- Preserve the platform guards and baselines declared in `Package.swift`.
- Define one top-level Swift type per file, named after that type. Keep related extensions with it or in `Type+Concern.swift`.
- Do not reorganize unrelated existing code solely to enforce these rules.

## Swift Practices

- Prefer type-safe generics and value types. Use the narrowest practical access level.
- Keep unprefixed APIs MainActor-first. Require `Sendable` for `nonisolated...` and `actor...` APIs and values crossing isolation boundaries.
- Treat `@unchecked Sendable`, `nonisolated(unsafe)`, detached tasks, and lock changes as exceptional; justify them with focused concurrency tests.
- Represent expected failures with typed errors and preserve underlying provider errors and resolution context.
- Add useful DocC documentation (`///`) to every new or modified public Swift declaration intended for downstream users. Document parameters, return values, thrown errors, and lifecycle or concurrency constraints when applicable.
- Update relevant guides or examples when public behavior changes.

## Tests and Validation

- Use XCTest in the matching test target; prefer a fresh `SkeinApplication` per test.
- Serialize tests that use global Skein state, and restore that state during cleanup.
- Follow `.swiftformat` and `.swiftlint.yml`; format only files in scope.
- Run `make format`, `make lint` and `make test` for Swift changes. Also run `make test-examples` or the relevant platform target when affected; use `make test-all` for broad changes.
