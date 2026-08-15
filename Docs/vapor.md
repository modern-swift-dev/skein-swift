# Vapor integration

[Documentation index](README.md)

The `SkeinVapor` product integrates Skein with Vapor 4.122 on macOS and Linux. It owns one `SkeinApplication` for each Vapor `Application`, installs request-scope middleware, makes the current `Request` injectable, and closes resolved resources during Vapor shutdown.

Add both products to the application target:

```swift
.product(name: "Skein", package: "skein-swift"),
.product(name: "SkeinVapor", package: "skein-swift")
```

The integration pins Vapor `4.122.0`. Skein retains its Swift 6.0 package baseline and its existing Apple deployment targets.

## Configure the application

Backend bindings must use the `nonisolated...` APIs when they are resolved from concurrent request handlers. Register request-lifetime dependencies in `VaporRequestScope`; they can resolve Vapor's exact `Request` instance like any other dependency.

```swift
import Skein
import SkeinVapor
import Vapor

struct RequestContext: Sendable {
    let request: Request
}

struct GreetingService: Sendable {
    let context: RequestContext

    func greeting() -> String {
        "Hello from \(context.request.url.path)"
    }
}

let backendModule = module {
    nonisolatedScoped(RequestContext.self, scope: VaporRequestScope.self) { resolver in
        RequestContext(request: try resolver.nonisolatedGet(Request.self))
    }
    nonisolatedScoped(GreetingService.self, scope: VaporRequestScope.self) { resolver in
        GreetingService(context: try resolver.nonisolatedGet())
    }
}

func configure(_ app: Application) async throws {
    try await app.skein.initialize {
        backendModule
    }

    app.get("hello") { request async throws -> String in
        let service: GreetingService = try request.skein.get()
        return service.greeting()
    }
}
```

Initialization validates declared roots and starts eager roots by default. Pass `validation: nil` to construct the container lazily without startup validation. Initialize Skein once during application configuration, before Vapor boots; a second call throws `SkeinVaporError.applicationAlreadyInitialized`.

The integration inserts its middleware at the beginning of Vapor's middleware chain. This makes the request scope available to every subsequently invoked middleware and route handler. Each request gets a distinct scope even if two requests have the same HTTP request ID.

## Resolve services

`request.skein.get` resolves Sendable nonisolated bindings from the request scope. Root singletons are shared by all request scopes, factories retain their normal behavior, and `VaporRequestScope` bindings are cached until that request finishes.

Both `app.skein` and `request.skein` provide:

- `get` overloads for ordinary and assisted nonisolated resolution;
- `actorGet` overloads for asynchronous global-actor resolution;
- qualifier arguments matching Skein's core resolution API.

Calling an application resolver before initialization throws `SkeinVaporError.applicationNotInitialized`. Calling a request resolver outside the installed middleware chain throws `SkeinVaporError.requestScopeUnavailable`.

## Lifetime and shutdown

The request scope closes after the downstream middleware and route handler return, whether they succeed or throw. Scoped `onClose` callbacks run at that point. Vapor closes the application-level Skein container during asynchronous application shutdown, disposing active scopes and singletons with Skein's normal ordering guarantees.

Use Vapor's asynchronous application lifecycle so Skein can await asynchronous disposal:

```swift
let app = try await Application.make(.production)
// Configure and run the application.
try await app.asyncShutdown()
```

In an async entry point, prefer an explicit `try await app.asyncShutdown()` on every exit path. Vapor's legacy synchronous `shutdown()` cannot safely wait for actor- or event-loop-isolated Skein disposers; the integration logs a warning when that path is used and does not promise deterministic cleanup.

A streamed response body can execute after its route handler has returned. Do not capture or resolve request-scoped services from a streaming body callback; its Skein scope is already closed. Application singletons may still be used if their own concurrency requirements permit it.
