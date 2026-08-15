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

@MainActor final class SkeinTests: XCTestCase {
    private static let globalSkeinTestLock = NSLock()

    nonisolated override func setUp() async throws {
        try await super.setUp()
        await MainActor.run {
            Self.globalSkeinTestLock.lock()
            stopSkein()
        }
    }

    nonisolated override func tearDown() async throws {
        await MainActor.run {
            stopSkein()
            Self.globalSkeinTestLock.unlock()
        }
        try await super.tearDown()
    }

    func testSingletonIsCreatedOnceAndFactoryCreatesEachTime() async throws {
        let definitions = module {
            single(Reference.self) { _ in Reference() }
            factory(FactoryValue.self) { resolver in
                FactoryValue(reference: try resolver.get())
            }
        }

        try startSkein { definitions }

        let first: Reference = try get()
        let second: Reference = try get()
        XCTAssertTrue(first === second)

        let firstFactory: FactoryValue = try get()
        let secondFactory: FactoryValue = try get()
        XCTAssertFalse(firstFactory === secondFactory)
        XCTAssertTrue(firstFactory.reference === secondFactory.reference)
    }

    func testSingletonIsCreatedExactlyOnceUnderConcurrentResolution() async throws {
        let constructions = LockedCounter()
        let failures = LockedCounter()
        let definitions = module {
            nonisolatedSingle(ConcurrentReference.self) { _ in
                constructions.increment()
                return ConcurrentReference()
            }
        }
        try startSkein { definitions }

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            do {
                let _: ConcurrentReference = try nonisolatedGet()
            } catch {
                failures.increment()
            }
        }

        XCTAssertEqual(failures.value, 0)
        XCTAssertEqual(constructions.value, 1)
    }

    func testModulesResolveProtocolBindingAcrossModules() async throws {
        let networking = module {
            single((any Client).self) { _ in TestClient() }
        }
        let feature = module {
            factory(FeatureService.self) { resolver in
                FeatureService(client: try resolver.get())
            }
        }

        try startSkein {
            networking
            feature
        }

        let service: FeatureService = try get()
        XCTAssertEqual(service.client.value, "client")
    }

    func testQualifiedBindingsAreIndependent() async throws {
        let definitions = module {
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }
            single(String.self, qualifier: ClientKind.background) { _ in "background" }
        }
        try startSkein { definitions }

        XCTAssertEqual(try get(String.self, qualifier: ClientKind.primary), "primary")
        XCTAssertEqual(try get(String.self, qualifier: ClientKind.background), "background")
    }

    func testEqualQualifierValuesFromDifferentTypesAreIndependent() async throws {
        let definitions = module {
            single(String.self, qualifier: PrimaryQualifier.primary) { _ in "first" }
            single(String.self, qualifier: SecondaryQualifier.primary) { _ in "second" }
        }
        try startSkein { definitions }

        XCTAssertEqual(try get(String.self, qualifier: PrimaryQualifier.primary), "first")
        XCTAssertEqual(try get(String.self, qualifier: SecondaryQualifier.primary), "second")
    }

    func testMissingBindingAndUnqualifiedLookupThrowSkeinError() async throws {
        let definitions = module {
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }
        }
        try startSkein { definitions }

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

    func testLifecycleAndDuplicateBindingErrors() async throws {
        XCTAssertThrowsError(try get(Reference.self)) { error in
            XCTAssertEqual(error as? SkeinError, .notStarted)
        }

        let definitions = module {
            single(Reference.self) { _ in Reference() }
        }
        try startSkein { definitions }

        XCTAssertThrowsError(try startSkein { definitions }) { error in
            XCTAssertEqual(error as? SkeinError, .alreadyStarted)
        }

        stopSkein()
        let duplicate = module {
            single(Reference.self) { _ in Reference() }
            factory(Reference.self) { _ in Reference() }
        }
        XCTAssertThrowsError(try startSkein { duplicate }) { error in
            guard case let .duplicateBinding(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a duplicate-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
    }

    func testCircularDependencyThrowsSkeinError() async throws {
        let definitions = module {
            factory(CycleA.self) { resolver in
                CycleA(dependency: try resolver.get())
            }
            factory(CycleB.self) { resolver in
                CycleB(dependency: try resolver.get())
            }
        }
        try startSkein { definitions }

        XCTAssertThrowsError(try get(CycleA.self)) { error in
            guard case let .circularDependency(path) = underlyingSkeinError(error) else {
                return XCTFail("Expected a circular-dependency error, got \(error)")
            }
            XCTAssertEqual(path.count, 3)
        }
    }

    func testStoppingAndRestartingCreatesFreshSingletons() async throws {
        let constructions = LockedCounter()
        let definitions = module {
            single(Reference.self) { _ in
                constructions.increment()
                return Reference()
            }
        }

        try startSkein { definitions }
        let first: Reference = try get()
        stopSkein()

        try startSkein { definitions }
        let second: Reference = try get()

        XCTAssertFalse(first === second)
        XCTAssertEqual(constructions.value, 2)
    }

    func testProviderErrorPropagatesAndSingletonCreationIsRetried() async throws {
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
        try startSkein { definitions }

        XCTAssertThrowsError(try get(String.self)) { error in
            XCTAssertEqual(
                (error as? SkeinResolutionError)?.underlying as? ProviderFailure,
                .failed
            )
        }
        XCTAssertEqual(try get(String.self), "available")
        XCTAssertEqual(attempts.count, 2)
    }

    func testMainActorSingletonAndFactoryRespectTheirLifetimes() async throws {
        let definitions = module {
            single(Reference.self) { _ in Reference() }
            single(MainActorService.self) { resolver in
                MainActorService(reference: try resolver.get())
            }
            factory(MainActorFactoryValue.self) { resolver in
                MainActorFactoryValue(service: try resolver.get())
            }
        }
        try startSkein { definitions }

        let singleton: MainActorService = try get()
        let sameSingleton: MainActorService = try get()
        let firstFactory: MainActorFactoryValue = try get()
        let secondFactory: MainActorFactoryValue = try get()

        XCTAssertTrue(singleton === sameSingleton)
        XCTAssertFalse(firstFactory === secondFactory)
        XCTAssertTrue(singleton === firstFactory.service)
        XCTAssertTrue(firstFactory.service === secondFactory.service)
    }

    func testNonisolatedResolutionRejectsMainActorBindingEvenAfterCaching() async throws {
        let definitions = module {
            single(MainActorService.self) { _ in MainActorService(reference: Reference()) }
        }
        try startSkein { definitions }

        let _: MainActorService = try get()

        let offActorError = await Task.detached { () -> SkeinError? in
            do {
                let _: MainActorService = try nonisolatedGet()
                return nil
            } catch {
                return underlyingSkeinError(error)
            }
        }.value
        guard case .bindingIsolationMismatch? = offActorError else {
            return XCTFail("Expected an isolation mismatch, got \(String(describing: offActorError))")
        }
    }

    func testValidatedStartupResolvesDeclaredEagerRoots() async throws {
        let definitions = module {
            single((any Client).self) { _ in TestClient() }.root(.eager)
            single(String.self, qualifier: ClientKind.primary) { _ in "primary" }.root(.eager)
        }

        try await startSkein(validation: .declaredRoots) {
            definitions
        }

        let client: any Client = try get()
        XCTAssertEqual(client.value, "client")
        XCTAssertEqual(try get(String.self, qualifier: ClientKind.primary), "primary")
        XCTAssertNotNil(currentSkeinValidationReport)
    }

    func testValidationRetainsSingletonsAndDoesNotCacheFactories() async throws {
        let singletonConstructions = LockedCounter()
        let factoryConstructions = LockedCounter()
        let definitions = module {
            single(Reference.self) { _ in
                singletonConstructions.increment()
                return Reference()
            }.root(.eager)
            factory(FactoryValue.self) { resolver in
                factoryConstructions.increment()
                return FactoryValue(reference: try resolver.get())
            }.root(.eager)
        }

        try await startSkein(validation: .declaredRoots) {
            definitions
        }

        let _: Reference = try get()
        let _: FactoryValue = try get()
        XCTAssertEqual(singletonConstructions.value, 1)
        XCTAssertEqual(factoryConstructions.value, 2)
    }

    func testValidationReportsCircularAndDuplicateBindings() async throws {
        let cyclic = module {
            factory(CycleA.self, using: CycleA.init).root()
            factory(CycleB.self, using: CycleB.init)
        }
        do {
            try await startSkein(validation: .declaredRoots) { cyclic }
            XCTFail("Expected circular dependency")
        } catch let GraphValidationError.circularDependency(path) {
            XCTAssertEqual(path.count, 3)
        }
        XCTAssertFalse(isSkeinStarted)

        let duplicate = module {
            single(Reference.self) { _ in Reference() }
            factory(Reference.self) { _ in Reference() }
        }
        XCTAssertThrowsError(try startSkein { duplicate }) { error in
            guard case let .duplicateBinding(type, qualifier) = underlyingSkeinError(error) else {
                return XCTFail("Expected a duplicate-binding error, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Reference.self))
            XCTAssertNil(qualifier)
        }
        XCTAssertFalse(isSkeinStarted)
    }

    func testLifecycleStateSupportsStartStopRestartAndConcurrentReads() async throws {
        XCTAssertFalse(isSkeinStarted)
        let definitions = module {
            single(Reference.self) { _ in Reference() }
        }
        try startSkein { definitions }
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
        try startSkein { definitions }
        XCTAssertTrue(isSkeinStarted)
    }

    func testFailedEagerValidationDoesNotRollbackEarlierProviderSideEffects() async throws {
        let factoryConstructions = LockedCounter()
        let definitions = module {
            factory(String.self) { _ in
                factoryConstructions.increment()
                return "validated first"
            }.root(.eager)
            factory(Reference.self) { _ in throw ProviderFailure.failed }.root(.eager)
        }

        do {
            try await startSkein(validation: .declaredRoots) {
                definitions
            }
            XCTFail("Expected provider failure")
        } catch {
            let providerError = (error as? SkeinResolutionError)?.underlying as? ProviderFailure
                ?? error as? ProviderFailure
            XCTAssertEqual(providerError, .failed)
        }
        XCTAssertEqual(factoryConstructions.value, 1)
        XCTAssertFalse(isSkeinStarted)
    }
}
