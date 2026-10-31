import Skein
import XCTest

@MainActor final class ScopeSlotReuseTests: XCTestCase {
    private enum ReusedScope: SkeinScope {}

    private final class ScopedValue: Sendable {}

    func testScopeIDCanBeReusedWhileThePreviousScopeIsStillClosing() async throws {
        let gate = LifecycleTestGate()
        let disposals = LockedCounter()
        let application = try SkeinApplication {
            module {
                scoped(ReusedScope.self, ScopedValue.self, onClose: { _ in
                    await gate.wait()
                    disposals.increment()
                }, provider: { _ in ScopedValue() })
            }
        }
        let previous = try application.createScope(ReusedScope.self, id: 1)
        let previousValue = try previous.get(ScopedValue.self, qualifier: nil)
        let closing = Task { await previous.close() }
        await gate.waitForArrivals(1)

        let replacement = try application.createScope(ReusedScope.self, id: 1)
        let replacementValue = try replacement.get(ScopedValue.self, qualifier: nil)

        XCTAssertFalse(previousValue === replacementValue)
        XCTAssertThrowsError(try application.createScope(ReusedScope.self, id: 1)) { error in
            guard case .duplicateScope = error as? SkeinError else {
                return XCTFail("Expected duplicateScope for the active replacement, got \(error)")
            }
        }
        await gate.open()
        await closing.value
        XCTAssertEqual(disposals.value, 1)
        XCTAssertNoThrow(try replacement.get(ScopedValue.self, qualifier: nil))
        await application.close()
        XCTAssertEqual(disposals.value, 2)
    }

    func testApplicationCloseAwaitsAScopeThatIsStillClosing() async throws {
        let gate = LifecycleTestGate()
        let events = LifecycleTestRecorder()
        let application = try SkeinApplication {
            module {
                scoped(ReusedScope.self, ScopedValue.self, onClose: { _ in
                    await gate.wait()
                    await events.append("scope disposed")
                }, provider: { _ in ScopedValue() })
            }
        }
        let scope = try application.createScope(ReusedScope.self, id: 1)
        _ = try scope.get(ScopedValue.self, qualifier: nil)
        let scopeClosing = Task { await scope.close() }
        await gate.waitForArrivals(1)

        let applicationClosing = Task {
            await application.close()
            await events.append("application closed")
        }
        for _ in 0 ..< 50 {
            await Task.yield()
        }
        let beforeOpening = await events.values
        XCTAssertEqual(beforeOpening, [], "The application must not finish closing while a scope is still disposing")

        await gate.open()
        await applicationClosing.value
        await scopeClosing.value
        let values = await events.values
        XCTAssertEqual(values, ["scope disposed", "application closed"])
    }
}
