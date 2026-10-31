@testable import Skein
import XCTest

@MainActor final class ScopeRootValidationTests: XCTestCase {
    private enum SessionScope: SkeinScope {}
    private enum RequestScope: SkeinScope {}
    private struct ScopeRootService {}
    private struct ScopedDependency {}
    private struct SharedDependency {}

    func testStructuralScopeRootWithMissingDependencyFailsValidatedStartup() async throws {
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                Module(bindings: [
                    scopedBinding(ScopeRootService.self, in: SessionScope.self, dependencies: [.init(ScopedDependency.self)]).root()
                ])
            }
            XCTFail("Expected validated startup to fail")
        } catch {
            guard case let .missingBinding(type, _, path) = error as? GraphValidationError else {
                return XCTFail("Expected missingBinding, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: ScopedDependency.self))
            XCTAssertEqual(path, [String(reflecting: ScopeRootService.self), String(reflecting: ScopedDependency.self)])
        }
    }

    func testScopeRootDependingOnAnotherScopeKindFailsWithCrossScopeDependency() async throws {
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                Module(bindings: [
                    scopedBinding(ScopeRootService.self, in: SessionScope.self, dependencies: [.init(ScopedDependency.self)]).root(),
                    scopedBinding(ScopedDependency.self, in: RequestScope.self, dependencies: [])
                ])
            }
            XCTFail("Expected validated startup to fail")
        } catch {
            guard case let .crossScopeDependency(_, from, to) = error as? GraphValidationError else {
                return XCTFail("Expected crossScopeDependency, got \(error)")
            }
            XCTAssertEqual(from, String(reflecting: SessionScope.self))
            XCTAssertEqual(to, String(reflecting: RequestScope.self))
        }
    }

    func testScopeRootIsolationViolationFailsWithIsolationMismatch() async throws {
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                Module(bindings: [
                    scopedBinding(
                        ScopeRootService.self,
                        in: SessionScope.self,
                        isolation: .nonisolated,
                        dependencies: [.init(ScopedDependency.self)]
                    ).root(),
                    scopedBinding(ScopedDependency.self, in: SessionScope.self, isolation: .mainActor, dependencies: [])
                ])
            }
            XCTFail("Expected validated startup to fail")
        } catch {
            guard case let .isolationMismatch(_, parent, dependency) = error as? GraphValidationError else {
                return XCTFail("Expected isolationMismatch, got \(error)")
            }
            XCTAssertEqual(parent, BindingIsolation.nonisolated.description)
            XCTAssertEqual(dependency, BindingIsolation.mainActor.description)
        }
    }

    func testValidScopeRootIsReportedWithoutRunningProviders() async throws {
        let application = try await SkeinApplication(validation: .declaredRoots) {
            Module(bindings: [
                scopedBinding(
                    ScopeRootService.self,
                    in: SessionScope.self,
                    dependencies: [.init(ScopedDependency.self), .init(SharedDependency.self)]
                ).root(),
                scopedBinding(ScopedDependency.self, in: SessionScope.self, dependencies: nil),
                scopedBinding(ScopedDependency.self, in: RequestScope.self, dependencies: []),
                Binding(
                    key: BindingKey(SharedDependency.self, qualifier: nil),
                    lifetime: .single,
                    isolation: .nonisolated,
                    provider: .nonisolated { _ in
                        XCTFail("Structural validation must not execute providers")
                        return SharedDependency()
                    },
                    dependencies: []
                )
            ])
            module {
                scoped(RequestScope.self, String.self) { _ in
                    XCTFail("Structural validation must not execute providers")
                    return "request"
                }.root()
            }
        }

        let opaque = try XCTUnwrap(application.startupValidationReport).opaqueBindings.map(\.type)
        XCTAssertEqual(opaque, [String(reflecting: ScopedDependency.self), String(reflecting: String.self)])
        await application.close()
    }

    func testEagerScopeRootIsRejectedAtApplicationConstruction() {
        XCTAssertThrowsError(
            try SkeinApplication {
                module {
                    scoped(SessionScope.self, String.self) { _ in "session" }.root(.eager)
                }
            }
        ) { error in
            XCTAssertEqual(
                error as? SkeinError,
                .eagerScopedRoot(type: String(reflecting: String.self), qualifier: nil)
            )
        }
    }

    private func scopedBinding(
        _ type: (some Any).Type,
        in scope: (some SkeinScope).Type,
        isolation: BindingIsolation = .mainActor,
        dependencies: [BindingDependency]?
    ) -> Binding {
        Binding(
            key: BindingKey(type, qualifier: nil),
            lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
            isolation: isolation,
            provider: .mainActor { _ in
                XCTFail("Structural validation must not execute providers")
                return 0
            },
            dependencies: dependencies
        )
    }
}
