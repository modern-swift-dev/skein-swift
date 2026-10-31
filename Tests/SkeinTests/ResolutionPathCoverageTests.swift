@testable import Skein
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
@MainActor final class ResolutionPathCoverageTests: XCTestCase {
    private enum CoverageScope: SkeinScope {}

    private final class MainScoped: Sendable {}
    private final class NonisolatedScoped: Sendable {}

    private struct Tagged: Sendable, Equatable {
        let source: String
        let value: Int
    }

    private struct ActorOnly: Sendable {}

    private enum CoverageQualifier: SkeinQualifier {
        case main
        case nonisolated
        case actor
    }

    // MARK: Scope actorGet

    func testScopeActorGetResolvesMainActorAndNonisolatedScopedBindings() async throws {
        let mainCreations = LockedCounter()
        let nonisolatedCreations = LockedCounter()
        let application = try SkeinApplication {
            module {
                scoped(CoverageScope.self, MainScoped.self) { _ in
                    mainCreations.increment()
                    return MainScoped()
                }
                nonisolatedScoped(CoverageScope.self, NonisolatedScoped.self) { _ in
                    nonisolatedCreations.increment()
                    return NonisolatedScoped()
                }
            }
        }
        let scope = try application.createScope(CoverageScope.self, id: 1)

        let main = try await scope.actorGet(MainScoped.self, qualifier: nil)
        let mainAgain = try await scope.actorGet(MainScoped.self, qualifier: nil)
        let nonisolated = try await scope.actorGet(NonisolatedScoped.self, qualifier: nil)
        let nonisolatedAgain = try await scope.actorGet(NonisolatedScoped.self, qualifier: nil)

        XCTAssertTrue(main === mainAgain)
        XCTAssertTrue(nonisolated === nonisolatedAgain)
        XCTAssertEqual(mainCreations.value, 1)
        XCTAssertEqual(nonisolatedCreations.value, 1)
        await scope.close()
    }

    func testScopeActorGetResolvesAssistedScopedBindingsOfEveryIsolation() async throws {
        // Skein has no public assisted scoped registrations, so scope the public assisted
        // factory bindings to reach each assisted branch of scoped actor resolution.
        let application = try SkeinApplication {
            Module(bindings: [
                scopedCopy(of: factory(Tagged.self, arguments: Int.self, qualifier: CoverageQualifier.main, provider: { _, value in
                    Tagged(source: "main", value: value)
                })),
                scopedCopy(of: nonisolatedFactory(Tagged.self, arguments: Int.self, qualifier: CoverageQualifier.nonisolated, provider: { _, value in
                    Tagged(source: "nonisolated", value: value)
                })),
                scopedCopy(of: actorFactory(
                    Tagged.self,
                    arguments: Int.self,
                    isolatedTo: LifecycleTestActor.self,
                    qualifier: CoverageQualifier.actor,
                    provider: { @LifecycleTestActor _, value in
                        Tagged(source: "actor", value: value)
                    }
                ))
            ])
        }
        let scope = try application.createScope(CoverageScope.self, id: 2)

        let main = try await scope.actorGet(Tagged.self, arguments: 1, qualifier: CoverageQualifier.main)
        let nonisolated = try await scope.actorGet(Tagged.self, arguments: 2, qualifier: CoverageQualifier.nonisolated)
        let actor = try await scope.actorGet(Tagged.self, arguments: 3, qualifier: CoverageQualifier.actor)

        XCTAssertEqual(main, Tagged(source: "main", value: 1))
        XCTAssertEqual(nonisolated, Tagged(source: "nonisolated", value: 2))
        XCTAssertEqual(actor, Tagged(source: "actor", value: 3))
        await scope.close()
    }

    // MARK: Application actorGet

    func testApplicationActorGetResolvesMainActorAndNonisolatedAssistedBindings() async throws {
        let application = try SkeinApplication {
            module {
                factory(Tagged.self, arguments: Int.self, qualifier: CoverageQualifier.main, provider: { _, value in
                    Tagged(source: "main", value: value)
                })
                nonisolatedFactory(Tagged.self, arguments: Int.self, qualifier: CoverageQualifier.nonisolated, provider: { _, value in
                    Tagged(source: "nonisolated", value: value)
                })
            }
        }

        let main = try await application.actorGet(Tagged.self, arguments: 4, qualifier: CoverageQualifier.main)
        let nonisolated = try await application.actorGet(Tagged.self, arguments: 5, qualifier: CoverageQualifier.nonisolated)

        XCTAssertEqual(main, Tagged(source: "main", value: 4))
        XCTAssertEqual(nonisolated, Tagged(source: "nonisolated", value: 5))
    }

    // MARK: Isolation and type errors

    // swiftformat:disable:next redundantAsync
    func testMainActorGetRejectsCustomActorBindings() async throws {
        let application = try SkeinApplication {
            module {
                actorSingle(ActorOnly.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor _ in ActorOnly() }
                actorScoped(CoverageScope.self, Tagged.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor _ in
                    Tagged(source: "actor", value: 0)
                }
            }
        }
        let scope = try application.createScope(CoverageScope.self, id: 3)
        let actorName = String(reflecting: LifecycleTestActor.self)

        XCTAssertThrowsError(try application.get(ActorOnly.self, qualifier: nil)) { error in
            XCTAssertEqual(
                underlying(error),
                .bindingIsolationMismatch(
                    type: String(reflecting: ActorOnly.self),
                    qualifier: nil,
                    required: "MainActor or nonisolated",
                    actual: actorName
                )
            )
        }
        XCTAssertThrowsError(try scope.get(Tagged.self, qualifier: nil)) { error in
            XCTAssertEqual(
                underlying(error),
                .bindingIsolationMismatch(
                    type: String(reflecting: Tagged.self),
                    qualifier: nil,
                    required: "MainActor or nonisolated",
                    actual: actorName
                )
            )
        }
    }

    // swiftformat:disable:next redundantAsync
    func testEagerAssistedRootIsRejectedAtApplicationConstruction() async {
        XCTAssertThrowsError(
            try SkeinApplication {
                module {
                    factory(Tagged.self, arguments: Int.self, provider: { _, value in Tagged(source: "main", value: value) })
                        .root(.eager)
                }
            }
        ) { error in
            XCTAssertEqual(
                error as? SkeinError,
                .eagerAssistedRoot(type: String(reflecting: Tagged.self), qualifier: nil)
            )
        }
    }

    // swiftformat:disable:next redundantAsync
    func testProviderValueOfWrongTypeFailsWithResolvedTypeMismatch() async throws {
        let application = try SkeinApplication {
            Module(bindings: [
                Binding(
                    key: BindingKey(Int.self, qualifier: nil),
                    lifetime: .factory,
                    isolation: .mainActor,
                    provider: .mainActor { _ in "not an integer" }
                )
            ])
        }

        XCTAssertThrowsError(try application.get(Int.self, qualifier: nil)) { error in
            XCTAssertEqual(
                underlying(error),
                .resolvedTypeMismatch(expected: String(reflecting: Int.self), actual: String(reflecting: String.self))
            )
        }
    }

    // MARK: Helpers

    private func scopedCopy(of binding: Binding) -> Binding {
        Binding(
            key: binding.key,
            lifetime: .scoped(type: ObjectIdentifier(CoverageScope.self), typeName: String(reflecting: CoverageScope.self)),
            isolation: binding.isolation,
            provider: binding.provider,
            disposer: binding.disposer,
            source: binding.source
        )
    }

    private func underlying(_ error: any Error) -> SkeinError? {
        (error as? SkeinResolutionError)?.underlying as? SkeinError
    }
}
