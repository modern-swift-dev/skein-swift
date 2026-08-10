# Testing with manual doubles

[Documentation index](README.md)

Use modules as a small composition root for each test. Start Koin with the dependencies the test needs and always stop it in teardown, so global state and singleton instances cannot leak into the next test.

```swift
import Koin
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
    override func tearDown() {
        stopKoin()
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
