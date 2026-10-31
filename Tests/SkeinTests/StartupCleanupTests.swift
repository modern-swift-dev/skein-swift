import Skein
import XCTest

final class StartupCleanupTests: XCTestCase {
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @MainActor func testFailedEagerStartupDisposesCompletedServicesBeforeThrowing() async throws {
        let disposals = LifecycleTestRecorder()
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                module {
                    single(
                        String.self,
                        onClose: { _ in await disposals.append("main") },
                        provider: { _ in "main" }
                    ).root(.eager)
                    actorSingle(
                        Int.self,
                        isolatedTo: LifecycleTestActor.self,
                        onClose: { @LifecycleTestActor _ in await disposals.append("actor") },
                        provider: { @LifecycleTestActor _ in 1 }
                    ).root(.eager)
                    nonisolatedSingle(Bool.self, provider: { _ in throw ProviderFailure.failed }).root(.eager)
                }
            }
            XCTFail("Expected eager startup failure")
        } catch {
            XCTAssertTrue(error is ProviderFailure)
        }
        let values = await disposals.values
        XCTAssertEqual(values, ["actor", "main"])
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @MainActor func testCancellationDuringLastEagerProviderDisposesItsResult() async throws {
        let gate = LifecycleTestGate()
        let disposals = LifecycleTestRecorder()
        let startup = Task { @MainActor in
            try await SkeinApplication(validation: .declaredRoots) {
                module {
                    actorSingle(
                        Int.self,
                        isolatedTo: LifecycleTestActor.self,
                        onClose: { @LifecycleTestActor _ in await disposals.append("actor") },
                        provider: { @LifecycleTestActor _ in
                            await gate.wait()
                            return 1
                        }
                    ).root(.eager)
                }
            }
        }
        await gate.waitForArrivals(1)
        startup.cancel()
        await gate.open()
        do {
            let application = try await startup.value
            await application.close()
            XCTFail("Expected cancelled startup to throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let values = await disposals.values
        XCTAssertEqual(values, ["actor"])
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @MainActor func testUnpublishedValidatedStartupClosesCandidateApplication() async throws {
        stopSkein()
        defer { stopSkein() }
        let gate = LifecycleTestGate()
        let disposals = LifecycleTestRecorder()
        let startup = Task { @MainActor in
            try await startSkein(validation: .declaredRoots) {
                module {
                    actorSingle(
                        Int.self,
                        isolatedTo: LifecycleTestActor.self,
                        onClose: { @LifecycleTestActor _ in await disposals.append("actor") },
                        provider: { @LifecycleTestActor _ in
                            await gate.wait()
                            return 1
                        }
                    ).root(.eager)
                }
            }
        }
        await gate.waitForArrivals(1)
        // Invalidate the startup token without cancelling the startup task, so the
        // candidate application is fully built but can no longer be published.
        GlobalSkein.lock.withLock { GlobalSkein.state = .idle }
        await gate.open()
        do {
            try await startup.value
            XCTFail("Expected unpublished startup to throw")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(isSkeinStarted)
        let values = await disposals.values
        XCTAssertEqual(values, ["actor"])
    }
}
