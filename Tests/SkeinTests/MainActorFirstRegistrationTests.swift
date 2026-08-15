import XCTest
@testable import Skein

private struct PackD1: Sendable { let value = 1 }
private struct PackD2: Sendable { let value = 2 }
private struct PackD3: Sendable { let value = 3 }
private struct PackD4: Sendable { let value = 4 }
private struct PackD5: Sendable { let value = 5 }
private struct PackD6: Sendable { let value = 6 }
private struct PackD7: Sendable { let value = 7 }
private struct PackD8: Sendable { let value = 8 }
private struct PackResult: Sendable { let value: Int }
private struct AssistedResult: Sendable { let value: String }
private struct ActorConstructed: Sendable { let value: Int }

private final class RegistrationReference {}
private protocol RegistrationService: AnyObject {}
extension RegistrationReference: RegistrationService {}

@globalActor private actor RegistrationDatabaseActor {
    static let shared = RegistrationDatabaseActor()
}

@RegistrationDatabaseActor
private func makeActorConstructed(_ dependency: PackD1) -> ActorConstructed {
    ActorConstructed(value: dependency.value)
}

final class MainActorFirstRegistrationTests: XCTestCase {
    @MainActor func testBuildersComposeBindingsAndModulesInDeclarationOrder() async throws {
        let includeOptional = true
        let optional: [Binding]? = [instance(PackD2())]
        let bindings = ModuleBuilder.buildBlock(
            ModuleBuilder.buildExpression(instance(PackD1())),
            ModuleBuilder.buildOptional(optional.map(ModuleBuilder.buildExpression)),
            ModuleBuilder.buildEither(first: ModuleBuilder.buildExpression(instance(PackD3()))),
            ModuleBuilder.buildArray([[instance(PackD4())], [instance(PackD5())]])
        )
        XCTAssertEqual(bindings.map(\.key.typeName), [
            String(reflecting: PackD1.self), String(reflecting: PackD2.self),
            String(reflecting: PackD3.self), String(reflecting: PackD4.self),
            String(reflecting: PackD5.self)
        ])

        let first = Module { instance(PackD6()) }
        let second = Module { if includeOptional { instance(PackD7()) } }
        let modules = SkeinApplicationBuilder.buildBlock(
            SkeinApplicationBuilder.buildExpression(first),
            SkeinApplicationBuilder.buildArray([[second]])
        )
        XCTAssertEqual(modules.count, 2)
    }

    @MainActor func testInstancePreservesReferenceIdentityAndProtocolExposure() async throws {
        let reference = RegistrationReference()
        let application = try SkeinApplication {
            module { instance((any RegistrationService).self, value: reference) }
        }
        let resolved: any RegistrationService = try application.get()
        XCTAssertTrue(resolved === reference)
    }

    @MainActor func testMainActorParameterPackSupportsEightDependencies() async throws {
        let application = try SkeinApplication {
            module {
                instance(PackD1()); instance(PackD2()); instance(PackD3()); instance(PackD4())
                instance(PackD5()); instance(PackD6()); instance(PackD7()); instance(PackD8())
                factory(PackResult.self, using: { (
                    d1: PackD1, d2: PackD2, d3: PackD3, d4: PackD4,
                    d5: PackD5, d6: PackD6, d7: PackD7, d8: PackD8
                ) in
                    PackResult(value: d1.value + d2.value + d3.value + d4.value
                               + d5.value + d6.value + d7.value + d8.value)
                })
            }
        }
        let result: PackResult = try application.get()
        XCTAssertEqual(result.value, 36)
    }

    @MainActor func testAssistedConstructorKeepsArgumentOutOfDependencyEdges() async throws {
        let root = factory(
            AssistedResult.self,
            arguments: String.self,
            using: { (argument: String, d1: PackD1, d2: PackD2, d3: PackD3,
                                 d4: PackD4, d5: PackD5) in
                AssistedResult(value: "\(argument):\(d1.value + d2.value + d3.value + d4.value + d5.value)")
            }
        ).root()
        XCTAssertEqual(root.dependencies?.count, 5)
        XCTAssertEqual(root.key.argumentTypeName, String(reflecting: String.self))

        let application = try SkeinApplication {
            module {
                instance(PackD1()); instance(PackD2()); instance(PackD3())
                instance(PackD4()); instance(PackD5()); root
            }
        }
        let result: AssistedResult = try application.get(arguments: "value")
        XCTAssertEqual(result.value, "value:15")
    }

    @MainActor func testNonisolatedInstancesAndConstructorPacksResolveOffActor() async throws {
        let constructor: @Sendable (
            PackD1, PackD2, PackD3, PackD4, PackD5
        ) -> PackResult = { d1, d2, d3, d4, d5 in
            PackResult(value: d1.value + d2.value + d3.value + d4.value + d5.value)
        }
        let application = try SkeinApplication {
            module {
                nonisolatedInstance(PackD1()); nonisolatedInstance(PackD2())
                nonisolatedInstance(PackD3()); nonisolatedInstance(PackD4())
                nonisolatedInstance(PackD5())
                nonisolatedFactory(PackResult.self, using: constructor)
            }
        }
        let result = try await Task.detached { try application.nonisolatedGet(PackResult.self) }.value
        XCTAssertEqual(result.value, 15)
    }

    @MainActor func testCustomActorProviderRecordsAndRunsOnDeclaredActor() async throws {
        let application = try SkeinApplication {
            module {
                actorInstance(PackD1(), isolatedTo: RegistrationDatabaseActor.self)
                actorFactory(
                    ActorConstructed.self,
                    isolatedTo: RegistrationDatabaseActor.self,
                    using: makeActorConstructed
                )
                actorFactory(PackResult.self, isolatedTo: RegistrationDatabaseActor.self, provider: {
                    @RegistrationDatabaseActor _ in PackResult(value: 42)
                })
            }
        }
        let result: PackResult = try await application.actorGet()
        let constructed: ActorConstructed = try await application.actorGet()
        XCTAssertEqual(result.value, 42)
        XCTAssertEqual(constructed.value, 1)
    }

    @MainActor func testCustomActorMismatchIsRejectedAtConstruction() async {
        XCTAssertThrowsError(try SkeinApplication {
            module {
                actorFactory(PackResult.self, isolatedTo: RegistrationDatabaseActor.self, provider: {
                    @MainActor _ in PackResult(value: 42)
                })
            }
        }) { error in
            guard case SkeinError.actorIsolationMismatch = error else {
                return XCTFail("Expected actorIsolationMismatch, got \(error)")
            }
        }
    }
}
