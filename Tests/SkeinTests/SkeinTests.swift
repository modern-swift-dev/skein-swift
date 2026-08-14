import Dispatch
import Foundation
@testable import Skein
import XCTest

private func underlyingSkeinError(_ error: any Error) -> SkeinError? {
    if let resolution = error as? SkeinResolutionError {
        return resolution.underlying as? SkeinError
    }
    if let configuration = error as? SkeinConfigurationError {
        return configuration.underlying
    }
    return error as? SkeinError
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

final class SkeinTests: XCTestCase {
    private static let globalSkeinTestLock = NSLock()

    override func setUp() {
        super.setUp()
        Self.globalSkeinTestLock.lock()
        stopSkein()
    }

    override func tearDown() {
        stopSkein()
        Self.globalSkeinTestLock.unlock()
        super.tearDown()
    }

    func testSingletonIsCreatedOnceAndFactoryCreatesEachTime() throws {
        let definitions = module {
            single(Reference.self) { _ in Reference() }
            factory(FactoryValue.self) { resolver in
                FactoryValue(reference: try resolver.get())
            }
        }

        try startSkein { modules(definitions) }

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
        try startSkein { modules(definitions) }

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

        try startSkein { modules(networking, feature) }

        let service: FeatureService = try get()
        XCTAssertEqual(service.client.value, "client")
    }

    func testQualifiedBindingsAreIndependent() throws {
        let definitions = module {
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }
            single(String.self, qualifier: ClientKind.background) { _ in "background" }
        }
        try startSkein { modules(definitions) }

        XCTAssertEqual(try get(String.self, qualifier: ClientKind.primary), "primary")
        XCTAssertEqual(try get(String.self, qualifier: ClientKind.background), "background")
    }

    func testEqualQualifierValuesFromDifferentTypesAreIndependent() throws {
        let definitions = module {
            single(String.self, qualifier: PrimaryQualifier.primary) { _ in "first" }
            single(String.self, qualifier: SecondaryQualifier.primary) { _ in "second" }
        }
        try startSkein { modules(definitions) }

        XCTAssertEqual(try get(String.self, qualifier: PrimaryQualifier.primary), "first")
        XCTAssertEqual(try get(String.self, qualifier: SecondaryQualifier.primary), "second")
    }

    func testMissingBindingAndUnqualifiedLookupThrowSkeinError() throws {
        let definitions = module {
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }
        }
        try startSkein { modules(definitions) }

        XCTAssertThrowsError(try get(Int.self)) { error in
            guard case let .missingBinding(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Int.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertThrowsError(try get(String.self)) { error in
            guard case let .missingBinding(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: String.self))
            XCTAssertNil(qualifier)
        }
    }

    func testLifecycleAndDuplicateBindingErrors() throws {
        XCTAssertThrowsError(try get(Reference.self)) { error in
            XCTAssertEqual(error as? SkeinError, .notStarted)
        }

        let definitions = module {
            single(Reference.self) { _ in Reference() }
        }
        try startSkein { modules(definitions) }

        XCTAssertThrowsError(try startSkein { modules(definitions) }) { error in
            XCTAssertEqual(error as? SkeinError, .alreadyStarted)
        }

        stopSkein()
        let duplicate = module {
            single(Reference.self) { _ in Reference() }
            factory(Reference.self) { _ in Reference() }
        }
        XCTAssertThrowsError(try startSkein { modules(duplicate) }) { error in
            guard case let .duplicateBinding(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a duplicate-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
    }

    func testCircularDependencyThrowsSkeinError() throws {
        let definitions = module {
            factory(CycleA.self) { resolver in
                CycleA(dependency: try resolver.get())
            }
            factory(CycleB.self) { resolver in
                CycleB(dependency: try resolver.get())
            }
        }
        try startSkein { modules(definitions) }

        XCTAssertThrowsError(try get(CycleA.self)) { error in
            guard case let .circularDependency(path) = underlyingSkeinError(error) else {
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

        try startSkein { modules(definitions) }
        let first: Reference = try get()
        stopSkein()

        try startSkein { modules(definitions) }
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
        try startSkein { modules(definitions) }

        XCTAssertThrowsError(try get(String.self)) { error in
            XCTAssertEqual(
                (error as? SkeinResolutionError)?.underlying as? ProviderFailure,
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
        try startSkein { modules(definitions) }

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
        try startSkein { modules(definitions) }

        let _: MainActorService = try mainActorGet()
        XCTAssertThrowsError(try get(MainActorService.self)) { error in
            guard case let .mainActorBindingRequiresMainActor(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a main-actor binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: MainActorService.self))
            XCTAssertNil(qualifier)
        }

        let offActorError = await Task.detached { () -> SkeinError? in
            do {
                let _: MainActorService = try get()
                return nil
            } catch {
                return underlyingSkeinError(error)
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

        try startSkein(
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

        try startSkein(
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
        XCTAssertThrowsError(try startSkein(validating: [DependencyProbe(Reference.self)]) {}) { error in
            guard case let .missingBinding(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertFalse(isSkeinStarted)

        let cyclic = module {
            factory(CycleA.self) { resolver in CycleA(dependency: try resolver.get()) }
            factory(CycleB.self) { resolver in CycleB(dependency: try resolver.get()) }
        }
        XCTAssertThrowsError(try startSkein(validating: [DependencyProbe(CycleA.self)]) { modules(cyclic) }) { error in
            guard case let .circularDependency(path) = underlyingSkeinError(error) else {
                return XCTFail("Expected a circular-dependency error, got \(error)")
            }
            XCTAssertEqual(path.count, 3)
        }
        XCTAssertFalse(isSkeinStarted)

        let duplicate = module {
            single(Reference.self) { _ in Reference() }
            factory(Reference.self) { _ in Reference() }
        }
        XCTAssertThrowsError(try startSkein(validating: []) { modules(duplicate) }) { error in
            guard case let .duplicateBinding(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a duplicate-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertFalse(isSkeinStarted)
    }

    func testLifecycleStateSupportsStartStopRestartAndConcurrentReads() throws {
        XCTAssertFalse(isSkeinStarted)
        let definitions = module {
            single(Reference.self) { _ in Reference() }
        }
        try startSkein { modules(definitions) }
        XCTAssertTrue(isSkeinStarted)

        let falseReads = LockedCounter()
        DispatchQueue.concurrentPerform(iterations: 128) { _ in
            if !isSkeinStarted {
                falseReads.increment()
            }
        }
        XCTAssertEqual(falseReads.value, 0)

        stopSkein()
        XCTAssertFalse(isSkeinStarted)
        try startSkein { modules(definitions) }
        XCTAssertTrue(isSkeinStarted)
    }

    @MainActor func testValidationReportsResolvedTypeMismatchAndDoesNotStartSkein() throws {
        let malformed = module {
            Binding(
                key: BindingKey(Reference.self, qualifier: nil),
                lifetime: .factory,
                provider: .standard { _ in "not a reference" }
            )
        }

        XCTAssertThrowsError(
            try startSkein(validating: [DependencyProbe(Reference.self)]) { modules(malformed) }
        ) { error in
            guard case let .resolvedTypeMismatch(expected, actual) = underlyingSkeinError(error) else {
                return XCTFail("Expected a resolved-type-mismatch error, got \(error)")
            }
            XCTAssertEqual(expected, String(reflecting: Reference.self))
            XCTAssertEqual(actual, String(reflecting: String.self))
        }
        XCTAssertFalse(isSkeinStarted)
        XCTAssertThrowsError(try get(Reference.self)) { error in
            XCTAssertEqual(error as? SkeinError, .notStarted)
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
            try startSkein(
                validating: [DependencyProbe(String.self), DependencyProbe(Reference.self)]
            ) {
                modules(definitions)
            }
        ) { error in
            guard case .missingBinding = underlyingSkeinError(error) else {
                return XCTFail("Expected a missing-binding error, got \(error)")
            }
        }
        XCTAssertEqual(factoryConstructions.value, 1)
        XCTAssertFalse(isSkeinStarted)
    }
}
