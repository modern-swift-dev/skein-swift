import Foundation
import Skein
import XCTest

private let skeinTestLock = NSLock()

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

private func makeProductionModule() -> Module {
    module {
        single((any GreetingService).self) { _ in LiveGreetingService() }
        factory(WelcomeMessage.self) { resolver in
            WelcomeMessage(service: try resolver.get())
        }
    }
}

private func makeTestModule() -> Module {
    module {
        single((any GreetingService).self) { _ in FakeGreetingService() }
        factory(WelcomeMessage.self) { resolver in
            WelcomeMessage(service: try resolver.get())
        }
    }
}

final class TestingExampleTests: XCTestCase {
    override func setUpWithError() throws {
        skeinTestLock.lock()
    }

    override func tearDown() {
        stopSkein()
        skeinTestLock.unlock()
        super.tearDown()
    }

    func testProductionGraph() throws {
        try startSkein { modules(makeProductionModule()) }

        let message: WelcomeMessage = try get()

        XCTAssertEqual(message.text, "Hello from production")
    }

    func testGraphWithHandWrittenFake() throws {
        try startSkein { modules(makeTestModule()) }

        let message: WelcomeMessage = try get()

        XCTAssertEqual(message.text, "Hello from a test")
    }
}
