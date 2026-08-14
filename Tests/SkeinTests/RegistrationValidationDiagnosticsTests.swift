@testable import Skein
import XCTest

private protocol RegistrationProtocol {}
private final class RegistrationImplementation: RegistrationProtocol {
    init() {}
}

private struct RegistrationD1 {}
private struct RegistrationD2 {}
private struct RegistrationD3 {}
private struct RegistrationD4 {}
private struct RegistrationFour {
    init(_: RegistrationD1, _: RegistrationD2, _: RegistrationD3, _: RegistrationD4) {}
}

private struct RegistrationTwo {
    init(_: RegistrationD1, _: RegistrationD2) {}
}

private struct RegistrationThree {
    init(_: RegistrationD1, _: RegistrationD2, _: RegistrationD3) {}
}

private final class RegistrationOne {
    init(_: RegistrationD1) {}
}

@MainActor private final class RegistrationMainActor {
    init(_: RegistrationD1) {}
}

@MainActor private final class RegistrationMainActorZero { init() {} }
@MainActor private final class RegistrationMainActorTwo {
    init(_: RegistrationD1, _: RegistrationD2) {}
}

@MainActor private final class RegistrationMainActorThree {
    init(_: RegistrationD1, _: RegistrationD2, _: RegistrationD3) {}
}

@MainActor private final class RegistrationMainActorFour {
    init(_: RegistrationD1, _: RegistrationD2, _: RegistrationD3, _: RegistrationD4) {}
}

private final class RegistrationNeedsMainActor {
    init(_: RegistrationMainActor) {}
}

private enum RegistrationProviderError: Error, Equatable { case failed }
private final class RegistrationNested {
    init(_: RegistrationD1) {}
}

private struct RegistrationScopeA: SkeinScope {}
private struct RegistrationScopeB: SkeinScope {}
private final class RegistrationCycleA { init(_: RegistrationCycleB) {} }
private final class RegistrationCycleB { init(_: RegistrationCycleA) {} }
private final class RegistrationSelfCycle { init() {} }

final class RegistrationValidationDiagnosticsTests: XCTestCase {
    func testConstructorRegistrationSupportsProtocolAndAritiesZeroThroughFour() throws {
        let application = try SkeinApplication {
            modules(module {
                factory((any RegistrationProtocol).self, using: RegistrationImplementation.init)
                factory(RegistrationD1.self, using: RegistrationD1.init)
                factory(RegistrationD2.self, using: RegistrationD2.init)
                factory(RegistrationD3.self, using: RegistrationD3.init)
                factory(RegistrationD4.self, using: RegistrationD4.init)
                single(RegistrationOne.self, using: RegistrationOne.init)
                factory(RegistrationTwo.self, using: RegistrationTwo.init)
                factory(RegistrationThree.self, using: RegistrationThree.init)
                factory(RegistrationFour.self, using: RegistrationFour.init)
            })
        }

        let implementation: any RegistrationProtocol = try application.get()
        XCTAssertTrue(implementation is RegistrationImplementation)
        let one: RegistrationOne = try application.get()
        XCTAssertNotNil(one)
        let two: RegistrationTwo = try application.get()
        XCTAssertNotNil(two)
        let three: RegistrationThree = try application.get()
        XCTAssertNotNil(three)
        let four: RegistrationFour = try application.get()
        XCTAssertNotNil(four)
    }

    @MainActor func testMainActorConstructorRegistrationCompilesAndResolvesDependencies() throws {
        let application = try SkeinApplication {
            modules(module {
                factory(RegistrationD1.self, using: RegistrationD1.init)
                factory(RegistrationD2.self, using: RegistrationD2.init)
                factory(RegistrationD3.self, using: RegistrationD3.init)
                factory(RegistrationD4.self, using: RegistrationD4.init)
                mainActorFactory(RegistrationMainActorZero.self, using: RegistrationMainActorZero.init)
                mainActorFactory(RegistrationMainActor.self, using: RegistrationMainActor.init)
                mainActorFactory(RegistrationMainActorTwo.self, using: RegistrationMainActorTwo.init)
                mainActorFactory(RegistrationMainActorThree.self, using: RegistrationMainActorThree.init)
                mainActorFactory(RegistrationMainActorFour.self, using: RegistrationMainActorFour.init)
            })
        }
        let value: RegistrationMainActor = try application.mainActorGet()
        XCTAssertNotNil(value)
        let zero: RegistrationMainActorZero = try application.mainActorGet()
        let two: RegistrationMainActorTwo = try application.mainActorGet()
        let three: RegistrationMainActorThree = try application.mainActorGet()
        let four: RegistrationMainActorFour = try application.mainActorGet()
        XCTAssertNotNil(zero)
        XCTAssertNotNil(two)
        XCTAssertNotNil(three)
        XCTAssertNotNil(four)
    }

    func testValidationDoesNotExecuteProvidersAndReportsOpaqueBindings() throws {
        var executions = 0
        let definition = module {
            single(RegistrationD1.self) { _ in
                executions += 1
                return RegistrationD1()
            }
            factory(RegistrationOne.self, using: RegistrationOne.init)
        }.validating(RegistrationOne.self)
        let application = try SkeinApplication { modules(definition) }

        let report = try application.validateGraph()

        XCTAssertEqual(executions, 0)
        XCTAssertEqual(report.opaqueBindings.count, 1)
        XCTAssertEqual(report.opaqueBindings.first?.type, String(reflecting: RegistrationD1.self))
    }

    func testValidationDetectsStandardToMainActorAndRootToScopeViolations() throws {
        let actorApplication = try SkeinApplication {
            modules(module {
                mainActorFactory(RegistrationMainActor.self, using: { RegistrationMainActor(RegistrationD1()) })
                factory(RegistrationNeedsMainActor.self, using: RegistrationNeedsMainActor.init)
            }.validating(RegistrationNeedsMainActor.self))
        }
        XCTAssertThrowsError(try actorApplication.validateGraph()) { error in
            guard case .mainActorDependencyRequiresMainActor = error as? GraphValidationError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let scopeApplication = try SkeinApplication {
            modules(module {
                scoped(RegistrationScopeA.self, RegistrationD1.self) { _ in RegistrationD1() }
                factory(RegistrationOne.self, using: RegistrationOne.init)
            }.validating(RegistrationOne.self))
        }
        XCTAssertThrowsError(try scopeApplication.validateGraph()) { error in
            guard case .rootDependsOnScopedBinding = error as? GraphValidationError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidationDetectsCrossScopeKnownEdge() throws {
        let source = SkeinSourceLocation(fileID: #fileID, line: #line)
        let parent = Binding(
            key: BindingKey(RegistrationOne.self, qualifier: nil),
            lifetime: .scoped(
                type: ObjectIdentifier(RegistrationScopeA.self),
                typeName: String(reflecting: RegistrationScopeA.self)
            ),
            provider: .standard { _ in RegistrationOne(RegistrationD1()) },
            source: source,
            dependencies: [.init(RegistrationD1.self)]
        )
        let child = Binding(
            key: BindingKey(RegistrationD1.self, qualifier: nil),
            lifetime: .scoped(
                type: ObjectIdentifier(RegistrationScopeB.self),
                typeName: String(reflecting: RegistrationScopeB.self)
            ),
            provider: .standard { _ in RegistrationD1() },
            source: source,
            dependencies: []
        )
        let definition = Module(bindings: [parent, child], validationRoots: [ValidationRoot(RegistrationOne.self)])
        let application = try SkeinApplication { modules(definition) }

        XCTAssertThrowsError(try application.validateGraph()) { error in
            guard case .crossScopeDependency = error as? GraphValidationError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidationDetectsMissingBindingAndKnownCycle() throws {
        let missing = try SkeinApplication {
            modules(module {
                factory(RegistrationOne.self, using: RegistrationOne.init)
            }.validating(RegistrationOne.self))
        }
        XCTAssertThrowsError(try missing.validateGraph()) { error in
            guard case .missingBinding = error as? GraphValidationError else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let cyclic = try SkeinApplication {
            modules(module {
                factory(RegistrationCycleA.self, using: RegistrationCycleA.init)
                factory(RegistrationCycleB.self, using: RegistrationCycleB.init)
            }.validating(RegistrationCycleA.self))
        }
        XCTAssertThrowsError(try cyclic.validateGraph()) { error in
            guard case let .circularDependency(path) = error as? GraphValidationError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(path.count, 3)
        }
    }

    func testDirectRuntimeSelfCycleKeepsBothTraceFrames() throws {
        let application = try SkeinApplication {
            modules(module {
                factory(RegistrationSelfCycle.self) { resolver in
                    try resolver.get(RegistrationSelfCycle.self)
                }
            })
        }

        XCTAssertThrowsError(try application.get(RegistrationSelfCycle.self)) { error in
            guard let resolution = error as? SkeinResolutionError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(resolution.path.map(\.type), [
                String(reflecting: RegistrationSelfCycle.self),
                String(reflecting: RegistrationSelfCycle.self)
            ])
        }
    }

    func testResolutionErrorRetainsProviderErrorAndRegistrationPath() throws {
        let leafLine = #line + 2
        let definition = module {
            factory(RegistrationD1.self) { _ in
                throw RegistrationProviderError.failed
            }
            factory(RegistrationNested.self, using: RegistrationNested.init)
        }
        let application = try SkeinApplication { modules(definition) }

        XCTAssertThrowsError(try application.get(RegistrationNested.self)) { error in
            guard let resolution = error as? SkeinResolutionError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(resolution.underlying as? RegistrationProviderError, .failed)
            XCTAssertEqual(resolution.path.map(\.type), [
                String(reflecting: RegistrationNested.self),
                String(reflecting: RegistrationD1.self)
            ])
            XCTAssertEqual(resolution.path.last?.registration?.fileID, #fileID)
            XCTAssertEqual(resolution.path.last?.registration?.line, UInt(leafLine))
        }
    }

    func testDuplicateBindingReportsBothSourceLocations() {
        let firstLine = #line + 2
        let definition = module {
            factory(RegistrationD1.self) { _ in RegistrationD1() }
            factory(RegistrationD1.self) { _ in RegistrationD1() }
        }
        XCTAssertThrowsError(try SkeinApplication { modules(definition) }) { error in
            guard let configuration = error as? SkeinConfigurationError else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(configuration.firstRegistration.line, UInt(firstLine))
            XCTAssertEqual(configuration.duplicateRegistration.line, UInt(firstLine + 1))
        }
    }
}
