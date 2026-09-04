import Skein
import XCTest

@MainActor final class AssistedArgumentTypeTests: XCTestCase {
    @MainActor class BaseArgument {}
    final class DerivedArgument: BaseArgument {}

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) func testDeclaredArgumentTypeSelectsBindingAcrossApplicationAndScopeAPIs() async throws {
        let application = try SkeinApplication {
            module {
                factory(String.self, arguments: BaseArgument.self, provider: { _, _ in "base" })
                factory(String.self, arguments: DerivedArgument.self, provider: { _, _ in "derived" })
                nonisolatedFactory(Bool.self, arguments: BaseArgument.self, provider: { _, _ in false })
                nonisolatedFactory(Bool.self, arguments: DerivedArgument.self, provider: { _, _ in true })
                actorFactory(
                    Int.self,
                    arguments: BaseArgument.self,
                    isolatedTo: MainActor.self,
                    provider: { @MainActor _, _ in 1 }
                )
                actorFactory(
                    Int.self,
                    arguments: DerivedArgument.self,
                    isolatedTo: MainActor.self,
                    provider: { @MainActor _, _ in 2 }
                )
            }
        }
        let scope = try application.createScope(SeededScope.self, id: "arguments")
        let derived = DerivedArgument()
        let base: BaseArgument = derived

        XCTAssertEqual(try application.get(String.self, arguments: base), "base")
        XCTAssertEqual(try application.get(String.self, arguments: derived), "derived")
        XCTAssertFalse(try application.nonisolatedGet(Bool.self, arguments: base))
        XCTAssertTrue(try application.nonisolatedGet(Bool.self, arguments: derived))
        let baseActor: Int = try await application.actorGet(arguments: base)
        let derivedActor: Int = try await application.actorGet(arguments: derived)
        XCTAssertEqual(baseActor, 1)
        XCTAssertEqual(derivedActor, 2)

        XCTAssertEqual(try scope.get(String.self, arguments: base), "base")
        XCTAssertEqual(try scope.get(String.self, arguments: derived), "derived")
        XCTAssertFalse(try scope.nonisolatedGet(Bool.self, arguments: base))
        XCTAssertTrue(try scope.nonisolatedGet(Bool.self, arguments: derived))
        let scopedBaseActor: Int = try await scope.actorGet(arguments: base)
        let scopedDerivedActor: Int = try await scope.actorGet(arguments: derived)
        XCTAssertEqual(scopedBaseActor, 1)
        XCTAssertEqual(scopedDerivedActor, 2)
        await application.close()
    }

    func testNilOptionalArgumentRemainsAnAssistedArgument() async throws {
        let application = try SkeinApplication {
            module {
                factory(String.self) { _ in "ordinary" }
                factory(String.self, arguments: Int?.self, provider: { _, value in
                    value.map(String.init) ?? "nil"
                })
            }
        }
        XCTAssertEqual(try application.get(String.self), "ordinary")
        XCTAssertEqual(try application.get(String.self, arguments: Int?.none), "nil")
        XCTAssertEqual(try application.get(String.self, arguments: Optional(7)), "7")
        await application.close()
    }
}
