import Foundation
import Skein
import XCTest

/// Exercises the process-wide API. Each test starts from and restores a stopped global application.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
@MainActor final class GlobalSkeinCoverageTests: XCTestCase {
    private struct Greeting: Sendable, Equatable {
        let text: String
    }

    private enum GreetingQualifier: SkeinQualifier {
        case formal
    }

    override nonisolated func setUp() async throws {
        try await super.setUp()
        await stopSkeinAndClose()
    }

    override nonisolated func tearDown() async throws {
        await stopSkeinAndClose()
        try await super.tearDown()
    }

    func testGlobalActorGetResolvesPlainQualifiedAndAssistedBindings() async throws {
        try startSkein {
            module {
                actorSingle(Greeting.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor _ in
                    Greeting(text: "hello")
                }
                actorSingle(Greeting.self, isolatedTo: LifecycleTestActor.self, qualifier: GreetingQualifier.formal) { @LifecycleTestActor _ in
                    Greeting(text: "good day")
                }
                actorFactory(Greeting.self, arguments: String.self, isolatedTo: LifecycleTestActor.self, provider: { @LifecycleTestActor _, name in
                    Greeting(text: "hello \(name)")
                })
            }
        }

        let plain: Greeting = try await actorGet()
        let formal = try await actorGet(Greeting.self, qualifier: GreetingQualifier.formal)
        let assisted = try await actorGet(Greeting.self, arguments: "skein")

        XCTAssertEqual(plain, Greeting(text: "hello"))
        XCTAssertEqual(formal, Greeting(text: "good day"))
        XCTAssertEqual(assisted, Greeting(text: "hello skein"))
    }

    func testGlobalNonisolatedGetResolvesAssistedBinding() throws {
        try startSkein {
            module {
                nonisolatedFactory(Greeting.self, arguments: String.self, provider: { _, name in Greeting(text: "hi \(name)") })
            }
        }

        let greeting = try nonisolatedGet(Greeting.self, arguments: "there")

        XCTAssertEqual(greeting, Greeting(text: "hi there"))
    }

    func testValidatedStartupThrowsAlreadyStartedWhileAnotherStartupIsRunning() async throws {
        let gate = LifecycleTestGate()
        let first = Task { @MainActor in
            try await startSkein(validation: .declaredRoots) {
                module {
                    actorSingle(Greeting.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor _ in
                        await gate.wait()
                        return Greeting(text: "first")
                    }.root(.eager)
                }
            }
        }
        await gate.waitForArrivals(1)

        do {
            try await startSkein(validation: .declaredRoots) {
                module { nonisolatedInstance(Greeting(text: "second")) }
            }
            XCTFail("Expected a concurrent validated startup to be rejected")
        } catch {
            XCTAssertEqual(error as? SkeinError, .alreadyStarted)
        }

        await gate.open()
        try await first.value
        let greeting: Greeting = try await actorGet()
        XCTAssertEqual(greeting, Greeting(text: "first"))
    }

    func testStartSkeinBuilderSupportsConditionalAndOptionalModules() throws {
        let includeFormal = true
        let useEnglish = false
        let optionalModule: Module? = module { nonisolatedInstance(Greeting(text: "optional"), qualifier: GreetingQualifier.formal) }
        try startSkein {
            if includeFormal {
                module { nonisolatedInstance(42) }
            }
            if useEnglish {
                module { nonisolatedInstance(Greeting(text: "hello")) }
            } else {
                module { nonisolatedInstance(Greeting(text: "bonjour")) }
            }
            if let optionalModule {
                optionalModule
            }
        }

        XCTAssertEqual(try nonisolatedGet(Int.self), 42)
        XCTAssertEqual(try nonisolatedGet(Greeting.self), Greeting(text: "bonjour"))
        XCTAssertEqual(try nonisolatedGet(Greeting.self, qualifier: GreetingQualifier.formal), Greeting(text: "optional"))
    }
}
