# Testing with manual doubles

[Documentation index](README.md)

Use modules as a small composition root for each test. Prefer a fresh `SkeinApplication` for every test: its registrations, singleton cache, scopes, and resolution state are isolated, so tests can run independently without touching global state.

The global API remains useful when testing application startup, but tests that use it must serialize their full start/resolve/stop lifetime. A teardown alone is insufficient when the test runner executes tests concurrently.

```swift
import Skein
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

@MainActor final class WelcomeServiceTests: XCTestCase {
    func testWelcomeMessage() throws {
        let testModule = module {
            single((any UserAPI).self, provider: { _ in FakeUserAPI() })
            factory(WelcomeService.self, using: WelcomeService.init)
        }
        let application = try SkeinApplication { testModule }

        let service: WelcomeService = try application.get()
        XCTAssertEqual(try service.message(), "Welcome, Ada")
    }
}
```

Make MainActor-first tests `@MainActor` and use `application.get`. For startup validation, mark bindings with `.root()` or `.root(.eager)` and use `try await SkeinApplication(validation: .declaredRoots)`. The retained report lists reached opaque providers.

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

The package does not currently provide a testing framework integration or automatic mock generation. Manual doubles keep the test setup within the existing Skein API.
