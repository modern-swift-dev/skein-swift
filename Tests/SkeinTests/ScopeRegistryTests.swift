import Skein
import XCTest

@MainActor final class ScopeRegistryTests: XCTestCase {
    func testClosingScopesOutOfOrderAndReusingIDsPreservesReverseCreationDisposal() async throws {
        let recorder = LifecycleTestRecorder()
        let application = try SkeinApplication {
            module {
                scoped(
                    SeededScope.self,
                    Int.self,
                    onClose: { value in await recorder.append(String(value)) },
                    provider: { _ in 0 }
                )
            }
        }
        var scopes: [SkeinScopeInstance<SeededScope>] = []
        for id in 0 ..< 128 {
            let scope = try application.createScope(SeededScope.self, id: id, seeding: id)
            scopes.append(scope)
        }
        for id in stride(from: 0, to: 128, by: 2) {
            await scopes[id].close()
        }
        let replacement = try application.createScope(SeededScope.self, id: 0, seeding: 128)
        XCTAssertEqual(try replacement.get(Int.self), 128)
        await application.close()

        let expected = stride(from: 0, to: 128, by: 2).map(String.init)
            + ["128"] + stride(from: 127, through: 1, by: -2).map(String.init)
        let events = await recorder.values
        XCTAssertEqual(events, expected)
        for scope in scopes {
            await scope.close()
        }
        let finalEvents = await recorder.values
        XCTAssertEqual(finalEvents, expected)
    }
}
