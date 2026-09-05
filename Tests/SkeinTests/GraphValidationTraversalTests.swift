@testable import Skein
import XCTest

@MainActor final class GraphValidationTraversalTests: XCTestCase {
    private struct Leaf {}
    private struct Branch {}
    private struct Trunk {}
    private struct Root {}

    func testSharedDependencyGraphReportsOpaqueLeafOnceWithoutExecutingProviders() async throws {
        let application = try SkeinApplication {
            Module(bindings: [
                binding(Leaf.self, dependencies: nil),
                binding(Branch.self, dependencies: Array(repeating: BindingDependency(Leaf.self), count: 32)).root(),
                binding(Trunk.self, dependencies: Array(repeating: BindingDependency(Branch.self), count: 32)).root(),
                binding(Root.self, dependencies: Array(repeating: BindingDependency(Trunk.self), count: 32)).root()
            ])
        }

        let report = try application.validateGraph()
        XCTAssertEqual(report.opaqueBindings.map(\.type), [String(reflecting: Leaf.self)])
        XCTAssertEqual(try application.validateGraph().opaqueBindings.map(\.type), report.opaqueBindings.map(\.type))
        await application.close()
    }

    func testPreviouslyValidatedDependencyStillChecksIncomingIsolation() async throws {
        let application = try SkeinApplication {
            Module(bindings: [
                binding(Leaf.self, dependencies: []).root(),
                Binding(
                    key: BindingKey(Root.self, qualifier: nil),
                    lifetime: .factory,
                    isolation: .nonisolated,
                    provider: .nonisolated { _ in Root() },
                    dependencies: [BindingDependency(Leaf.self)]
                ).root()
            ])
        }

        XCTAssertThrowsError(try application.validateGraph()) { error in
            guard case let .isolationMismatch(path, _, _) = error as? GraphValidationError else {
                return XCTFail("Expected isolation mismatch, got \(error)")
            }
            XCTAssertEqual(path, [String(reflecting: Root.self), String(reflecting: Leaf.self)])
        }
        await application.close()
    }

    private func binding(_ type: (some Any).Type, dependencies: [BindingDependency]?) -> Binding {
        Binding(
            key: BindingKey(type, qualifier: nil),
            lifetime: .factory,
            isolation: .mainActor,
            provider: .mainActor { _ in
                XCTFail("Structural validation must not execute providers")
                return 0
            },
            dependencies: dependencies
        )
    }
}
