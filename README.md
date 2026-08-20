# Skein for Swift

`Skein` is a small, type-safe dependency-injection container for Swift. Its default API is MainActor-isolated, with explicit Sendable nonisolated and custom-global-actor alternatives.

Read the [Skein website](https://modern-swift-dev.github.io/skein-swift/) or browse the [source repository](https://github.com/modern-swift-dev/skein-swift).

## Why Skein?

A skein is a length of thread gathered into a connected bundle. The name reflects how this library brings the individual threads of an application's dependency graph together into one explicit, inspectable composition.

## Install

Add `https://github.com/modern-swift-dev/skein-swift` as a package dependency in Xcode, or add it to a Swift Package Manager manifest:

```swift
dependencies: [
    .package(
        url: "https://github.com/modern-swift-dev/skein-swift",
        from: "1.0.1"
    )
]
```

Then depend on the `Skein` product:

```swift
.product(name: "Skein", package: "skein-swift")
```

Vapor 4 applications can instead add the `SkeinVapor` product alongside `Skein`. The integration is available on macOS 15 and Linux and pins Vapor 4.122.0.

## Quick start

Bindings declare their exposed type and receive a `Resolver` for their own dependencies. A `single` is created once on first use; a `factory` creates a new value for every resolution.

```swift
import Skein

protocol HTTPClient { }
final class URLSessionClient: HTTPClient { }

final class UserService {
    init(client: any HTTPClient) { }
}

let appModule = module {
    single((any HTTPClient).self, provider: { _ in URLSessionClient() })
    factory(UserService.self, using: UserService.init)
}

try startSkein {
    appModule
}

let service: UserService = try get()
stopSkein()
```

All setup and resolution operations that can fail use Swift error handling, so call them with `try` and handle failures appropriate to your application.

## Documentation

Start with the hosted guides:

- [Overview](https://modern-swift-dev.github.io/skein-swift/)
- [Documentation index](https://modern-swift-dev.github.io/skein-swift/documentation/)
- [Getting started](https://modern-swift-dev.github.io/skein-swift/documentation/getting-started/)
- [Examples](https://modern-swift-dev.github.io/skein-swift/examples/)

The site publishes separate API references for each library product:

- [Skein API](https://modern-swift-dev.github.io/skein-swift/api/skein/)
- [SkeinSwiftUI API](https://modern-swift-dev.github.io/skein-swift/api/skein-swiftui/)
- [SkeinVapor API](https://modern-swift-dev.github.io/skein-swift/api/skein-vapor/)

Each stable GitHub release includes `Skein-Documentation.zip`, containing the three matching `.doccarchive` bundles. Download and unzip it, then open each bundle in Xcode to add it to the Documentation browser.

Build the same archive locally with:

```sh
make documentation
```

## Runnable examples

The [`Examples`](Examples/README.md) package contains independent, executable use cases for:

- singleton and factory lifetimes;
- dependency chains and module composition;
- protocol-oriented registrations;
- qualified bindings;
- lifecycle and provider-error handling;
- MainActor-first services, binding-owned roots, and async startup validation;
- test isolation and hand-written fakes.

Run any example directly from the repository root:

```sh
swift run --package-path Examples BasicUsage
swift run --package-path Examples ModularComposition
swift run --package-path Examples QualifiedBindings
swift run --package-path Examples ErrorHandling
swift run --package-path Examples MainActorValidation
swift test --package-path Examples
```

These examples depend on the local checkout of Skein, so they also serve as compile-checked usage references while the API evolves.

## Work on the website

The Astro source is in `Website/`. Install its locked dependencies with:

```sh
make site-setup
```

Build the Astro pages and all three static DocC sites, validate their internal links, then replace `docs/` with the finished output:

```sh
make site-build
```

After a successful build, preview the assembled site from `docs/`:

```sh
make site-preview
```

Run the internal-link check again without rebuilding:

```sh
make site-check
```

The existing `make documentation` command remains separate. It creates `Skein-Documentation.zip` for GitHub releases rather than the GitHub Pages site.

## Publish a release and site update

The site build reads the latest published, stable GitHub release. Publish the GitHub release before rebuilding the site. The existing release workflow runs when you push a semantic-version tag.

1. Push the release tag and wait for GitHub to publish the release.
2. Run `make site-build`.
3. Review the rendered release version, date, notes, and generated DocC changes.
4. Commit the updated `docs/` directory.

GitHub Pages needs one repository setting before its first deployment. In [Settings > Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site), choose **Deploy from a branch**, then select the `main` branch and `/docs` folder. The local build does not change this remote setting.
