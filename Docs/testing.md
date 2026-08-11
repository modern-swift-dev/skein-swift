# Testing with manual doubles

[Documentation index](README.md)

Use modules as a small composition root for each test. Start Koin with the dependencies the test needs and always stop it in teardown, so global state and singleton instances cannot leak into the next test.

Because Koin is global, tests that use it must also serialize their full start/resolve/stop lifetime. A teardown alone is insufficient when the test runner executes tests concurrently. Keep a test-only lock for the duration of each test and release it after `stopKoin()`.

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
    private static let koinLock = NSLock()

    override func setUpWithError() throws {
        Self.koinLock.lock()
    }

    override func tearDown() {
        stopKoin()
        Self.koinLock.unlock()
        super.tearDown()
    }

    func testWelcomeMessage() throws {
        let testModule = module {
            single((any UserAPI).self) { _ in FakeUserAPI() }
            factory(WelcomeService.self) { resolver in
                WelcomeService(api: try resolver.get())
            }
        }
        try startKoin { modules(testModule) }

        let service: WelcomeService = try get()
        XCTAssertEqual(try service.message(), "Welcome, Ada")
    }
}
```

For tests with main-actor services, make the test `@MainActor` and use `mainActorGet`. For startup validation tests, call `startKoin(validating:manifest)` within the same serialized lifetime; validated singletons may already be instantiated, and factories have run once.

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
