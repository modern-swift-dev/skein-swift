import Dispatch
import Foundation
@testable import Skein
import XCTest

private struct ConvenienceScope: SkeinScope {}
private struct OtherConvenienceScope: SkeinScope {}

private func countedModules(_ counter: LockedCounter, value: Int) -> [Module] {
    counter.increment()
    return modules(module { single(Int.self) { _ in value } })
}

private func countedInvalidModules(_ counter: LockedCounter) -> [Module] {
    counter.increment()
    return modules(module {
        single(String.self) { _ in "invalid-first" }
        factory(String.self) { _ in "invalid-second" }
    })
}

final class LifecycleConvenienceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        stopSkein()
    }

    override func tearDown() {
        stopSkein()
        super.tearDown()
    }

    func testModuleOverlayWinsOnlyExactTypedRegistrationIdentity() throws {
        let base = module {
            single(String.self) { _ in "base-root" }
            factory(String.self, arguments: Int.self) { _, value in "base-int:\(value)" }
            factory(String.self, arguments: Bool.self) { _, value in "base-bool:\(value)" }
            scoped(ConvenienceScope.self, String.self) { _ in "base-scope" }
            scoped(OtherConvenienceScope.self, String.self) { _ in "other-scope" }
        }
        let overlay = module {
            factory(String.self) { _ in "overlay-root" }
            factory(String.self, arguments: Int.self) { _, value in "overlay-int:\(value)" }
            scoped(ConvenienceScope.self, String.self) { _ in "overlay-scope" }
        }

        let application = try SkeinApplication { modules(base.overriding(overlay)) }
        XCTAssertEqual(try application.get(String.self), "overlay-root")
        XCTAssertEqual(try application.get(String.self, arguments: 2), "overlay-int:2")
        XCTAssertEqual(try application.get(String.self, arguments: true), "base-bool:true")

        let scope = try application.createScope(ConvenienceScope.self, id: 1)
        let otherScope = try application.createScope(OtherConvenienceScope.self, id: 1)
        XCTAssertEqual(try scope.get(String.self), "overlay-scope")
        XCTAssertEqual(try otherScope.get(String.self), "other-scope")

        // The source modules are reusable and unchanged.
        let baseApplication = try SkeinApplication { modules(base) }
        XCTAssertEqual(try baseApplication.get(String.self), "base-root")
        let overlayApplication = try SkeinApplication { modules(overlay) }
        XCTAssertEqual(try overlayApplication.get(String.self), "overlay-root")
    }

    func testModuleOverlayPreservesDuplicateErrorsWithinEachInput() throws {
        let duplicateBase = module {
            single(String.self) { _ in "first" }
            factory(String.self) { _ in "second" }
        }
        let overlay = module {
            single(String.self) { _ in "overlay" }
        }
        XCTAssertThrowsError(
            try SkeinApplication { modules(duplicateBase.overriding(overlay)) }
        ) { error in
            guard case .duplicateBinding = (error as? SkeinConfigurationError)?.underlying else {
                return XCTFail("Expected duplicateBinding, got \(error)")
            }
        }

        let base = module { single(Int.self) { _ in 1 } }
        let duplicateOverlay = module {
            single(String.self) { _ in "first" }
            factory(String.self) { _ in "second" }
        }
        XCTAssertThrowsError(
            try SkeinApplication { modules(base.overriding(duplicateOverlay)) }
        ) { error in
            guard case .duplicateBinding = (error as? SkeinConfigurationError)?.underlying else {
                return XCTFail("Expected duplicateBinding, got \(error)")
            }
        }
    }

    func testStartSkeinIfNeededPublishesExactlyOneConcurrentCandidate() throws {
        let configurations = LockedCounter()
        let starts = LockedCounter()
        let failures = LockedCounter()

        DispatchQueue.concurrentPerform(iterations: 64) { index in
            do {
                let started = try startSkeinIfNeeded {
                    countedModules(configurations, value: index)
                }
                if started {
                    starts.increment()
                }
            } catch {
                failures.increment()
            }
        }

        XCTAssertEqual(configurations.value, 1)
        XCTAssertEqual(starts.value, 1)
        XCTAssertEqual(failures.value, 0)
        let _: Int = try get()
    }

    func testStartSkeinIfNeededRetainsExistingApplicationWithoutBuildingCandidate() throws {
        XCTAssertTrue(try startSkeinIfNeeded {
            modules(module { single(String.self) { _ in "installed" } })
        })

        let configurations = LockedCounter()
        let didStart = try startSkeinIfNeeded {
            countedInvalidModules(configurations)
        }

        XCTAssertFalse(didStart)
        XCTAssertEqual(configurations.value, 0)
        XCTAssertEqual(try get(String.self), "installed")
    }

    func testStartSkeinIfNeededThrowsInvalidConstructionWhenStopped() {
        XCTAssertThrowsError(
            try startSkeinIfNeeded {
                modules(module {
                    single(String.self) { _ in "first" }
                    factory(String.self) { _ in "second" }
                })
            }
        ) { error in
            guard case .duplicateBinding = (error as? SkeinConfigurationError)?.underlying else {
                return XCTFail("Expected duplicateBinding, got \(error)")
            }
        }
        XCTAssertFalse(isSkeinStarted)
    }

    func testGlobalAssistedResolutionAndStopWithClose() async throws {
        let disposals = LockedCounter()
        try startSkein {
            modules(module {
                factory(String.self, arguments: Int.self) { _, value in "value:\(value)" }
                single(
                    Int.self,
                    onClose: { _ in disposals.increment() },
                    provider: { _ in 42 }
                )
            })
        }

        XCTAssertEqual(try get(String.self, arguments: 7), "value:7")
        let _: Int = try get()
        await stopSkeinAndClose()

        XCTAssertEqual(disposals.value, 1)
        XCTAssertFalse(isSkeinStarted)
    }
}
