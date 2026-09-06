---
title: "Skein for Swift"
description: "A MainActor-first, type-safe dependency-injection container for Swift."
---

Dependency injection for Swift

# Make the graph explicit.

Skein registers the services your app owns, resolves them by type, and keeps UI-oriented graphs on MainActor by default.

[Get started](/docs/skein-swift/documentation/getting-started/) · [View on GitHub ↗](https://github.com/modern-swift-dev/skein-swift)

A small application module

```swift
import Skein

let appModule = module {
    single((any HTTPClient).self, provider: { _ in URLSessionClient() })
    factory(UserService.self, using: UserService.init)
}

try startSkein { appModule }
let service: UserService = try get()
stopSkein()
```

## Capabilities

Register values as lazy singletons, factories, and typed scopes. Use constructor injection, assisted factories, protocol bindings, qualifiers, and modules that compose by feature.

## Platform support

Skein uses Swift 6 and supports macOS 15, iOS 17, tvOS 17, watchOS 10, and visionOS 1. The optional Vapor integration also supports Linux.

## Source and docs

The package, DocC articles, and executable examples are kept in the open repository. Stable releases include matching DocC archives.

[Inspect the source ↗](https://github.com/modern-swift-dev/skein-swift)

Registration has consequences

## Pick a lifetime where the dependency is declared.

A `single` is lazy and cached after it resolves successfully. A `factory` runs every time. Constructor registrations record their dependencies, which lets Skein inspect declared roots before startup.

single

`get()` → one cached value

The provider runs on the first successful resolution. Later lookups return that value.

factory

`get()` → new value

The provider runs for every resolution. Its dependencies may still be singletons.

Choose a lifetime at registration time. Skein keeps that decision visible in the module.

Latest stable release

## Skein {{version}}

Published {{releaseDate}}

Use this version when adding Skein with Swift Package Manager.

`.package(url: "https://github.com/modern-swift-dev/skein-swift.git", from: "{{version}}")`

{{releaseNotes}}

[Read release notes ↗]({{releaseURL}})

Built around Swift isolation

## MainActor first. Explicit when it is not.

Unprefixed APIs keep UI graphs concise. Use the `nonisolated...` APIs for Sendable dependencies outside MainActor, or the async `actor...` APIs for your own global actor.

[Read the module guides →](/docs/skein-swift/documentation/)

Start with the useful bits

## [Getting started](/docs/skein-swift/documentation/getting-started/)

Create a module, start an application, resolve a service, and validate declared roots.

[Read more →](/docs/skein-swift/documentation/getting-started/)

## [Runnable examples](/docs/skein-swift/examples/)

Read the source that ships in this repository, then run each example with Swift Package Manager.

[Read more →](/docs/skein-swift/examples/)
