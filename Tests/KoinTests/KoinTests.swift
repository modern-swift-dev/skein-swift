import Dispatch
import Foundation
@testable import Koin
import XCTest

private func underlyingKoinError(_ error: any Error) -> KoinError? {
    if let resolution = error as? KoinResolutionError {
        return resolution.underlying as? KoinError
    }
    if let configuration = error as? KoinConfigurationError {
        return configuration.underlying
    }
    return error as? KoinError
}

@MainActor private final class MainActorService {
    let reference: Reference

    init(reference: Reference) {
        self.reference = reference
    }
}

@MainActor private final class MainActorFactoryValue {
    let service: MainActorService

    init(service: MainActorService) {
        self.service = service
    }
}

final class KoinTests: XCTestCase {
    private static let globalKoinTestLock = NSLock()

    override func setUp() {
        super.setUp()
        Self.globalKoinTestLock.lock()
        stopKoin()
    }

    override func tearDown() {
        stopKoin()
        Self.globalKoinTestLock.unlock()
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
            guard case let .missingBinding(type, qualifier) = underlyingKoinError(error) else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Int.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertThrowsError(try get(String.self)) { error in
            guard case let .missingBinding(type, qualifier) = underlyingKoinError(error) else {
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
            guard case let .duplicateBinding(type, qualifier) = underlyingKoinError(error) else {
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
            guard case let .circularDependency(path) = underlyingKoinError(error) else {
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
            XCTAssertEqual(
                (error as? KoinResolutionError)?.underlying as? ProviderFailure,
                .failed
            )
        }
        XCTAssertEqual(try get(String.self), "available")
        XCTAssertEqual(attempts.count, 2)
    }

    @MainActor func testMainActorSingletonAndFactoryRespectTheirLifetimes() throws {
        let definitions = module {
            single(Reference.self) { _ in Reference() }
            mainActorSingle(MainActorService.self) { resolver in
                MainActorService(reference: try resolver.get())
            }
            mainActorFactory(MainActorFactoryValue.self) { resolver in
                MainActorFactoryValue(service: try resolver.mainActorGet())
            }
        }
        try startKoin { modules(definitions) }

        let singleton: MainActorService = try mainActorGet()
        let sameSingleton: MainActorService = try mainActorGet()
        let firstFactory: MainActorFactoryValue = try mainActorGet()
        let secondFactory: MainActorFactoryValue = try mainActorGet()

        XCTAssertTrue(singleton === sameSingleton)
        XCTAssertFalse(firstFactory === secondFactory)
        XCTAssertTrue(singleton === firstFactory.service)
        XCTAssertTrue(firstFactory.service === secondFactory.service)
    }

    @MainActor func testOrdinaryResolutionRejectsMainActorBindingEvenAfterCaching() async throws {
        let definitions = module {
            mainActorSingle(MainActorService.self) { _ in MainActorService(reference: Reference()) }
        }
        try startKoin { modules(definitions) }

        let _: MainActorService = try mainActorGet()
        XCTAssertThrowsError(try get(MainActorService.self)) { error in
            guard case let .mainActorBindingRequiresMainActor(type, qualifier) = underlyingKoinError(error) else {
                return XCTFail("Expected a main-actor binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: MainActorService.self))
            XCTAssertNil(qualifier)
        }

        let offActorError = await Task.detached { () -> KoinError? in
            do {
                let _: MainActorService = try get()
                return nil
            } catch {
                return underlyingKoinError(error)
            }
        }.value
        guard case let .mainActorBindingRequiresMainActor(type, qualifier)? = offActorError else {
            return XCTFail("Expected a main-actor binding error, got \(String(describing: offActorError))")
        }
        XCTAssertEqual(type, String(reflecting: MainActorService.self))
        XCTAssertNil(qualifier)
    }

    @MainActor func testValidatedStartupProbesProtocolAndQualifiedBindings() throws {
        let definitions = module {
            single((any Client).self) { _ in TestClient() }
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }
        }

        try startKoin(
            validating: [
                DependencyProbe((any Client).self),
                DependencyProbe(String.self, qualifier: ClientKind.primary)
            ]
        ) {
            modules(definitions)
        }

        let client: any Client = try mainActorGet()
        XCTAssertEqual(client.value, "client")
        XCTAssertEqual(try mainActorGet(String.self, qualifier: ClientKind.primary), "primary")
    }

    @MainActor func testValidationRetainsSingletonsAndDoesNotCacheFactories() throws {
        let singletonConstructions = LockedCounter()
        let factoryConstructions = LockedCounter()
        let definitions = module {
            single(Reference.self) { _ in
                singletonConstructions.increment()
                return Reference()
            }
            factory(FactoryValue.self) { resolver in
                factoryConstructions.increment()
                return FactoryValue(reference: try resolver.get())
            }
        }

        try startKoin(
            validating: [DependencyProbe(Reference.self), DependencyProbe(FactoryValue.self)]
        ) {
            modules(definitions)
        }

        let _: Reference = try mainActorGet()
        let _: FactoryValue = try mainActorGet()
        XCTAssertEqual(singletonConstructions.value, 1)
        XCTAssertEqual(factoryConstructions.value, 2)
    }

    @MainActor func testValidationReportsMissingCircularAndDuplicateBindings() throws {
        XCTAssertThrowsError(try startKoin(validating: [DependencyProbe(Reference.self)]) {}) { error in
            guard case let .missingBinding(type, qualifier) = underlyingKoinError(error) else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertFalse(isKoinStarted)

        let cyclic = module {
            factory(CycleA.self) { resolver in CycleA(dependency: try resolver.get()) }
            factory(CycleB.self) { resolver in CycleB(dependency: try resolver.get()) }
        }
        XCTAssertThrowsError(try startKoin(validating: [DependencyProbe(CycleA.self)]) { modules(cyclic) }) { error in
            guard case let .circularDependency(path) = underlyingKoinError(error) else {
                return XCTFail("Expected a circular-dependency error, got \(error)")
            }
            XCTAssertEqual(path.count, 3)
        }
        XCTAssertFalse(isKoinStarted)

        let duplicate = module {
            single(Reference.self) { _ in Reference() }
            factory(Reference.self) { _ in Reference() }
        }
        XCTAssertThrowsError(try startKoin(validating: []) { modules(duplicate) }) { error in
            guard case let .duplicateBinding(type, qualifier) = underlyingKoinError(error) else {
                return XCTFail("Expected a duplicate-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertFalse(isKoinStarted)
    }

    func testLifecycleStateSupportsStartStopRestartAndConcurrentReads() throws {
        XCTAssertFalse(isKoinStarted)
        let definitions = module {
            single(Reference.self) { _ in Reference() }
        }
        try startKoin { modules(definitions) }
        XCTAssertTrue(isKoinStarted)

        let falseReads = LockedCounter()
        DispatchQueue.concurrentPerform(iterations: 128) { _ in
            if !isKoinStarted {
                falseReads.increment()
            }
        }
        XCTAssertEqual(falseReads.value, 0)

        stopKoin()
        XCTAssertFalse(isKoinStarted)
        try startKoin { modules(definitions) }
        XCTAssertTrue(isKoinStarted)
    }

    @MainActor func testValidationReportsResolvedTypeMismatchAndDoesNotStartKoin() throws {
        let malformed = module {
            Binding(
                key: BindingKey(Reference.self, qualifier: nil),
                lifetime: .factory,
                provider: .standard { _ in "not a reference" }
            )
        }

        XCTAssertThrowsError(
            try startKoin(validating: [DependencyProbe(Reference.self)]) { modules(malformed) }
        ) { error in
            guard case let .resolvedTypeMismatch(expected, actual) = underlyingKoinError(error) else {
                return XCTFail("Expected a resolved-type-mismatch error, got \(error)")
            }
            XCTAssertEqual(expected, String(reflecting: Reference.self))
            XCTAssertEqual(actual, String(reflecting: String.self))
        }
        XCTAssertFalse(isKoinStarted)
        XCTAssertThrowsError(try get(Reference.self)) { error in
            XCTAssertEqual(error as? KoinError, .notStarted)
        }
    }

    @MainActor func testFailedValidationDoesNotRollbackEarlierProviderSideEffects() throws {
        let factoryConstructions = LockedCounter()
        let definitions = module {
            factory(String.self) { _ in
                factoryConstructions.increment()
                return "validated first"
            }
        }

        XCTAssertThrowsError(
            try startKoin(
                validating: [DependencyProbe(String.self), DependencyProbe(Reference.self)]
            ) {
                modules(definitions)
            }
        ) { error in
            guard case .missingBinding = underlyingKoinError(error) else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
        }
        XCTAssertEqual(factoryConstructions.value, 1)
        XCTAssertFalse(isKoinStarted)
    }
}
