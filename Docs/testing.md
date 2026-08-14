# Testing with manual doubles

[Documentation index](README.md)

Use modules as a small composition root for each test. Prefer a fresh `KoinApplication` for every test: its registrations, singleton cache, scopes, and resolution state are isolated, so tests can run independently without touching global state.

The global API remains useful when testing application startup, but tests that use it must serialize their full start/resolve/stop lifetime. A teardown alone is insufficient when the test runner executes tests concurrently.

```swift
import Koin
import Foundation
import XCTest

protocol UserAPI {
    func currentName() throws -> String
}

final class FakeUserAPI: UserAPI {
    func currentName() throws -> String { "Ada" }
}

final class WelcomeService {
    private let api: any UserAPI

    init(api: any UserAPI) {
        self.api = api
    }

    func message() throws -> String {
        "Welcome, \(try api.currentName())"
    }
}

final class WelcomeServiceTests: XCTestCase {
    func testWelcomeMessage() throws {
        let testModule = module {
            single((any UserAPI).self) { _ in FakeUserAPI() }
            factory(WelcomeService.self) { resolver in
                WelcomeService(api: try resolver.get())
            }
        }
        let application = try KoinApplication { modules(testModule) }

        let service: WelcomeService = try application.get()
        XCTAssertEqual(try service.message(), "Welcome, Ada")
    }
}
```

For tests with main-actor services, make the test `@MainActor` and use `application.mainActorGet`. For startup validation tests, use `KoinApplication(validating:manifest)` on the main actor. Runtime probes can instantiate values; structural `validateGraph()` does not execute providers and reports reached closure registrations as opaque.

For a test that needs to inspect calls or return different values, use a manually written fake that stores the state your assertion needs. Register it as a `single` when the system under test and the assertion must observe the same fake instance.

```swift
final class RecordingUserAPI: UserAPI {
    private(set) var calls = 0

    func currentName() throws -> String {
        calls += 1
        return "Ada"
    }
}
```

The package does not currently provide a testing framework integration or automatic mock generation. Manual doubles keep the test setup within the existing Koin API.
