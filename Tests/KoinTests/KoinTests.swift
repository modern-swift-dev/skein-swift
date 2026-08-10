import Dispatch
@testable import Koin
import XCTest

final class KoinTests: XCTestCase {
    override func tearDown() {
        stopKoin()
        super.tearDown()
    }

    func testSingletonIsCreatedOnceAndFactoryCreatesEachTime() throws {
        let definitions = module {
            single(Reference.self) { _ in Reference() }
            factory(FactoryValue.self) { resolver in
                FactoryValue(reference: try resolver.get())
            }
        }

        try startKoin { modules(definitions) }

        let first: Reference = try get()
        let second: Reference = try get()
        XCTAssertTrue(first === second)

        let firstFactory: FactoryValue = try get()
        let secondFactory: FactoryValue = try get()
        XCTAssertFalse(firstFactory === secondFactory)
        XCTAssertTrue(firstFactory.reference === secondFactory.reference)
    }

    func testSingletonIsCreatedExactlyOnceUnderConcurrentResolution() throws {
        let constructions = LockedCounter()
        let failures = LockedCounter()
        let definitions = module {
            single(ConcurrentReference.self) { _ in
                constructions.increment()
                return ConcurrentReference()
            }
        }
        try startKoin { modules(definitions) }

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            do {
                let _: ConcurrentReference = try get()
            } catch {
                failures.increment()
            }
        }

        XCTAssertEqual(failures.value, 0)
        XCTAssertEqual(constructions.value, 1)
    }

    func testModulesResolveProtocolBindingAcrossModules() throws {
        let networking = module {
            single((any Client).self) { _ in TestClient() }
        }
        let feature = module {
            factory(FeatureService.self) { resolver in
                FeatureService(client: try resolver.get())
            }
        }

        try startKoin { modules(networking, feature) }

        let service: FeatureService = try get()
        XCTAssertEqual(service.client.value, "client")
    }

    func testQualifiedBindingsAreIndependent() throws {
        let definitions = module {
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }
            single(String.self, qualifier: ClientKind.background) { _ in "background" }
        }
        try startKoin { modules(definitions) }

        XCTAssertEqual(try get(String.self, qualifier: ClientKind.primary), "primary")
        XCTAssertEqual(try get(String.self, qualifier: ClientKind.background), "background")
    }

    func testEqualQualifierValuesFromDifferentTypesAreIndependent() throws {
        let definitions = module {
            single(String.self, qualifier: PrimaryQualifier.primary) { _ in "first" }
            single(String.self, qualifier: SecondaryQualifier.primary) { _ in "second" }
        }
        try startKoin { modules(definitions) }

        XCTAssertEqual(try get(String.self, qualifier: PrimaryQualifier.primary), "first")
        XCTAssertEqual(try get(String.self, qualifier: SecondaryQualifier.primary), "second")
    }

    func testMissingBindingAndUnqualifiedLookupThrowKoinError() throws {
        let definitions = module {
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }
        }
        try startKoin { modules(definitions) }

        XCTAssertThrowsError(try get(Int.self)) { error in
            guard case let .missingBinding(type, qualifier) = error as? KoinError else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Int.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertThrowsError(try get(String.self)) { error in
            guard case let .missingBinding(type, qualifier) = error as? KoinError else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: String.self))
            XCTAssertNil(qualifier)
        }
    }

    func testLifecycleAndDuplicateBindingErrors() throws {
        XCTAssertThrowsError(try get(Reference.self)) { error in
            XCTAssertEqual(error as? KoinError, .notStarted)
        }

        let definitions = module {
            single(Reference.self) { _ in Reference() }
        }
        try startKoin { modules(definitions) }

        XCTAssertThrowsError(try startKoin { modules(definitions) }) { error in
            XCTAssertEqual(error as? KoinError, .alreadyStarted)
        }

        stopKoin()
        let duplicate = module {
            single(Reference.self) { _ in Reference() }
            factory(Reference.self) { _ in Reference() }
        }
        XCTAssertThrowsError(try startKoin { modules(duplicate) }) { error in
            guard case let .duplicateBinding(type, qualifier) = error as? KoinError else {
                return XCTFail("Expected a duplicate-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
    }

    func testCircularDependencyThrowsKoinError() throws {
        let definitions = module {
            factory(CycleA.self) { resolver in
                CycleA(dependency: try resolver.get())
            }
            factory(CycleB.self) { resolver in
                CycleB(dependency: try resolver.get())
            }
        }
        try startKoin { modules(definitions) }

        XCTAssertThrowsError(try get(CycleA.self)) { error in
            guard case let .circularDependency(path) = error as? KoinError else {
                return XCTFail("Expected a circular-dependency error, got \(error)")
            }
            XCTAssertEqual(path.count, 3)
        }
    }

    func testStoppingAndRestartingCreatesFreshSingletons() throws {
        let constructions = LockedCounter()
        let definitions = module {
            single(Reference.self) { _ in
                constructions.increment()
                return Reference()
            }
        }

        try startKoin { modules(definitions) }
        let first: Reference = try get()
        stopKoin()

        try startKoin { modules(definitions) }
        let second: Reference = try get()

        XCTAssertFalse(first === second)
        XCTAssertEqual(constructions.value, 2)
    }

    func testProviderErrorPropagatesAndSingletonCreationIsRetried() throws {
        let attempts = AttemptCounter()
        let definitions = module {
            single(String.self) { _ in
                attempts.count += 1
                if attempts.count == 1 {
                    throw ProviderFailure.failed
                }
                return "available"
            }
        }
        try startKoin { modules(definitions) }

        XCTAssertThrowsError(try get(String.self)) { error in
            XCTAssertEqual(error as? ProviderFailure, .failed)
        }
        XCTAssertEqual(try get(String.self), "available")
        XCTAssertEqual(attempts.count, 2)
    }
}
