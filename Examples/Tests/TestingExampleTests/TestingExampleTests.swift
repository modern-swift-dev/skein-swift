import Skein
import XCTest

private protocol GreetingService {
    func greeting() -> String
}

private final class LiveGreetingService: GreetingService {
    func greeting() -> String {
        "Hello from production"
    }
}

private final class FakeGreetingService: GreetingService {
    func greeting() -> String {
        "Hello from a test"
    }
}

private final class WelcomeMessage {
    private let service: any GreetingService

    init(service: any GreetingService) {
        self.service = service
    }

    var text: String {
        service.greeting()
    }
}

@MainActor private func makeProductionModule() -> Module {
    module {
        single((any GreetingService).self, provider: { _ in LiveGreetingService() })
        factory(WelcomeMessage.self, using: WelcomeMessage.init)
    }
}

@MainActor private func makeTestModule() -> Module {
    module {
        single((any GreetingService).self, provider: { _ in FakeGreetingService() })
        factory(WelcomeMessage.self, using: WelcomeMessage.init)
    }
}

@MainActor final class TestingExampleTests: XCTestCase {
    func testProductionGraph() throws {
        let application = try SkeinApplication { makeProductionModule() }
        let message: WelcomeMessage = try application.get()

        XCTAssertEqual(message.text, "Hello from production")
    }

    func testGraphWithHandWrittenFake() throws {
        let application = try SkeinApplication { makeTestModule() }
        let message: WelcomeMessage = try application.get()

        XCTAssertEqual(message.text, "Hello from a test")
    }
}
