@testable import Skein
import XCTest

@MainActor final class ScopeSeedingTests: XCTestCase {
    // swiftformat:disable:next redundantAsync
    func testSeededServiceIsReturnedAndProviderIsBypassed() async throws {
        let constructions = LockedCounter()
        let application = try SkeinApplication {
            module {
                nonisolatedScoped(SeededScope.self, SeededService.self) { _ in
                    constructions.increment()
                    return SeededService()
                }
            }
        }
        let seeded = SeededService()

        let scope = try application.createScope(SeededScope.self, id: "seeded", seeding: seeded)

        let first: SeededService = try scope.nonisolatedGet()
        let second: SeededService = try scope.nonisolatedGet()
        XCTAssertTrue(first === seeded)
        XCTAssertTrue(second === seeded)
        XCTAssertEqual(constructions.value, 0)
    }

    func testSeededServiceUsesBindingDisposerExactlyOnce() async throws {
        let disposals = LockedCounter()
        let seeded = SeededService()
        let application = try SkeinApplication {
            module {
                nonisolatedScoped(
                    SeededScope.self,
                    SeededService.self,
                    onClose: { value in
                        XCTAssertTrue(value === seeded)
                        disposals.increment()
                    },
                    provider: { _ in SeededService() }
                )
            }
        }
        let scope = try application.createScope(SeededScope.self, id: "disposal", seeding: seeded)

        await scope.close()
        await scope.close()

        XCTAssertEqual(disposals.value, 1)
    }

    // swiftformat:disable:next redundantAsync
    func testFailedSeedDoesNotAttachScope() async throws {
        let application = try SkeinApplication {
            module {
                nonisolatedScoped(SeededScope.self, String.self) { _ in "ordinary" }
            }
        }

        XCTAssertThrowsError(
            try application.createScope(SeededScope.self, id: "reusable", seeding: SeededService())
        ) { error in
            guard case .missingBinding = error as? SkeinError else {
                return XCTFail("Expected missingBinding, got \(error)")
            }
        }

        let scope = try application.createScope(SeededScope.self, id: "reusable")
        XCTAssertEqual(try scope.nonisolatedGet(String.self), "ordinary")
    }

    func testSeededScopePreservesApplicationAndDuplicateValidation() async throws {
        let application = try SkeinApplication {
            module {
                nonisolatedScoped(SeededScope.self, SeededService.self) { _ in SeededService() }
            }
        }
        let scope = try application.createScope(
            SeededScope.self,
            id: "duplicate",
            seeding: SeededService()
        )

        XCTAssertThrowsError(
            try application.createScope(
                SeededScope.self,
                id: "duplicate",
                seeding: SeededService()
            )
        ) { error in
            guard case .duplicateScope = error as? SkeinError else {
                return XCTFail("Expected duplicateScope, got \(error)")
            }
        }

        await scope.close()
        await application.close()

        XCTAssertThrowsError(
            try application.createScope(
                SeededScope.self,
                id: "closed",
                seeding: SeededService()
            )
        ) { error in
            XCTAssertEqual(error as? SkeinError, .applicationClosed)
        }
    }

    // swiftformat:disable:next redundantAsync
    func testOrdinaryScopeCreationStillUsesAndCachesProvider() async throws {
        let constructions = LockedCounter()
        let application = try SkeinApplication {
            module {
                nonisolatedScoped(SeededScope.self, SeededService.self) { _ in
                    constructions.increment()
                    return SeededService()
                }
            }
        }
        let scope = try application.createScope(SeededScope.self, id: "ordinary")

        let first: SeededService = try scope.nonisolatedGet()
        let second: SeededService = try scope.nonisolatedGet()

        XCTAssertTrue(first === second)
        XCTAssertEqual(constructions.value, 1)
    }
}
