import Skein
import XCTest

final class ScopeRootLifecycleTests: XCTestCase {
    @MainActor func testClosedScopeRejectsRootAndAssistedResolutionOnEverySurface() async throws {
        let creations = LockedCounter()
        let application = try SkeinApplication {
            module {
                nonisolatedFactory(Int.self) { _ in
                    creations.increment()
                    return 1
                }
                nonisolatedFactory(Int.self, arguments: String.self, provider: { _, _ in
                    creations.increment()
                    return 2
                })
            }
        }
        let scope = try application.createScope(SeededScope.self, id: "closed-root")
        await scope.close()
        let expected = SkeinError.scopeClosed(scope: String(reflecting: SeededScope.self), id: "closed-root")
        XCTAssertThrowsError(try scope.get(Int.self)) {
            XCTAssertEqual(($0 as? SkeinResolutionError)?.underlying as? SkeinError, expected)
        }
        XCTAssertThrowsError(try scope.nonisolatedGet(Int.self)) {
            XCTAssertEqual(($0 as? SkeinResolutionError)?.underlying as? SkeinError, expected)
        }
        XCTAssertThrowsError(try scope.get(Int.self, arguments: "value")) {
            XCTAssertEqual(($0 as? SkeinResolutionError)?.underlying as? SkeinError, expected)
        }
        XCTAssertThrowsError(try scope.nonisolatedGet(Int.self, arguments: "value")) {
            XCTAssertEqual(($0 as? SkeinResolutionError)?.underlying as? SkeinError, expected)
        }
        do {
            _ = try await scope.actorGet(Int.self)
            XCTFail("Expected closed scope to reject root")
        } catch {
            XCTAssertEqual((error as? SkeinResolutionError)?.underlying as? SkeinError, expected)
        }
        do {
            _ = try await scope.actorGet(Int.self, arguments: "value")
            XCTFail("Expected closed scope to reject assisted root")
        } catch {
            XCTAssertEqual((error as? SkeinResolutionError)?.underlying as? SkeinError, expected)
        }
        XCTAssertEqual(creations.value, 0)
        XCTAssertEqual(try application.nonisolatedGet(Int.self), 1)
        await application.close()
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @MainActor func testScopeClosedDuringRootResolutionRejectsResultWithoutClosingRoot() async throws {
        let gate = LifecycleTestGate()
        let disposals = LifecycleTestRecorder()
        let application = try SkeinApplication {
            module {
                actorSingle(
                    Int.self,
                    isolatedTo: LifecycleTestActor.self,
                    onClose: { @LifecycleTestActor _ in await disposals.append("root") },
                    provider: { @LifecycleTestActor _ in
                        await gate.wait()
                        return 1
                    }
                )
            }
        }
        let scope = try application.createScope(SeededScope.self, id: "in-flight-root")
        let resolving = Task { try await scope.actorGet(Int.self) }
        await gate.waitForArrivals(1)
        await scope.close()
        await gate.open()
        do {
            _ = try await resolving.value
            XCTFail("Expected scopeClosed after root resolution")
        } catch {
            guard case .scopeClosed = (error as? SkeinResolutionError)?.underlying as? SkeinError else {
                return XCTFail("Expected scopeClosed, got \(error)")
            }
        }
        let value: Int = try await application.actorGet()
        XCTAssertEqual(value, 1)
        let beforeClose = await disposals.values
        XCTAssertTrue(beforeClose.isEmpty)
        await application.close()
        let afterClose = await disposals.values
        XCTAssertEqual(afterClose, ["root"])
    }
}
