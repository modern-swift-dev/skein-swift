import Skein
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
final class WaiterCancellationTests: XCTestCase {
    private final class SharedValue: Sendable {}
    private final class WaitingValue: Sendable {}
    private final class AwaitedValue: Sendable {}
    private enum SharedScope: SkeinScope {}

    @MainActor func testCancelledApplicationWaiterThrowsCancellationErrorBeforeSharedCreationFinishes() async throws {
        let gate = LifecycleTestGate()
        let creations = LockedCounter()
        let application = try SkeinApplication {
            module {
                actorSingle(SharedValue.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor _ in
                    creations.increment()
                    await gate.wait()
                    return SharedValue()
                }
            }
        }

        let first = Task { try await application.actorGet(SharedValue.self) }
        await gate.waitForArrivals(1)
        let cancelledReturned = expectation(description: "cancelled waiter returned")
        let cancelled = Task {
            defer { cancelledReturned.fulfill() }
            return try await application.actorGet(SharedValue.self)
        }
        cancelled.cancel()
        await fulfillment(of: [cancelledReturned], timeout: 2)
        let second = Task { try await application.actorGet(SharedValue.self) }
        await gate.open()

        await assertBareCancellation(cancelled)
        let firstValue = try await first.value
        let secondValue = try await second.value
        XCTAssertTrue(firstValue === secondValue)
        XCTAssertEqual(creations.value, 1)
    }

    @MainActor func testCancelledScopeWaiterThrowsCancellationErrorBeforeSharedCreationFinishes() async throws {
        let gate = LifecycleTestGate()
        let creations = LockedCounter()
        let application = try SkeinApplication {
            module {
                actorScoped(SharedScope.self, SharedValue.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor _ in
                    creations.increment()
                    await gate.wait()
                    return SharedValue()
                }
            }
        }
        let scope = try application.createScope(SharedScope.self, id: 1)

        let first = Task { try await scope.actorGet(SharedValue.self) }
        await gate.waitForArrivals(1)
        let cancelledReturned = expectation(description: "cancelled scope waiter returned")
        let cancelled = Task {
            defer { cancelledReturned.fulfill() }
            return try await scope.actorGet(SharedValue.self)
        }
        cancelled.cancel()
        await fulfillment(of: [cancelledReturned], timeout: 2)
        let second = Task { try await scope.actorGet(SharedValue.self) }
        await gate.open()

        await assertBareCancellation(cancelled)
        let firstValue = try await first.value
        let secondValue = try await second.value
        XCTAssertTrue(firstValue === secondValue)
        XCTAssertEqual(creations.value, 1)
        await scope.close()
    }

    /// A cancelled waiter inside a creation must remove its wait edge. Otherwise the
    /// awaited creation resolving the waiting one would be reported as a false cycle.
    @MainActor func testCancelledWaiterRemovesItsAsyncWaitEdge() async throws {
        let awaitedGate = LifecycleTestGate()
        let waitingGate = LifecycleTestGate()
        let waiterReturned = expectation(description: "nested waiter returned")
        let application = try SkeinApplication {
            module {
                actorSingle(AwaitedValue.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor resolver in
                    await awaitedGate.wait()
                    _ = try await resolver.actorGet(WaitingValue.self)
                    return AwaitedValue()
                }
                actorSingle(WaitingValue.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor resolver in
                    let waiter = Task { try await resolver.actorGet(AwaitedValue.self) }
                    waiter.cancel()
                    _ = await waiter.result
                    waiterReturned.fulfill()
                    await waitingGate.wait()
                    return WaitingValue()
                }
            }
        }

        let awaited = Task { try await application.actorGet(AwaitedValue.self) }
        await awaitedGate.waitForArrivals(1)
        let waiting = Task { try await application.actorGet(WaitingValue.self) }
        await fulfillment(of: [waiterReturned], timeout: 2)
        await awaitedGate.open()
        await waitingGate.open()

        _ = try await waiting.value
        _ = try await awaited.value
    }

    @MainActor private func assertBareCancellation(
        _ task: Task<some Any, Error>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await task.value
            XCTFail("Expected the cancelled waiter to throw", file: file, line: line)
        } catch {
            XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)", file: file, line: line)
        }
    }
}
