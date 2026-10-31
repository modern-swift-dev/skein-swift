import Skein
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
@MainActor final class ScopedConstructorRegistrationTests: XCTestCase {
    private enum SessionScope: SkeinScope {}
    private enum RequestScope: SkeinScope {}

    private enum Flavor: SkeinQualifier {
        case special
    }

    /// An application-lifetime dependency.
    private struct Config: Sendable {
        let name: String
    }

    /// A dependency scoped to the same scope kind as the service under test.
    private final class Session: Sendable {}

    private final class Service: Sendable {
        let config: Config
        let session: Session

        init(config: Config, session: Session) {
            self.config = config
            self.session = session
        }
    }

    // MARK: Resolution

    // swiftformat:disable:next redundantAsync
    func testScopedConstructorResolvesDependenciesFromTheScopeInBothArgumentOrders() async throws {
        let creations = LockedCounter()
        let application = try SkeinApplication {
            module {
                nonisolatedInstance(Config(name: "config"))
                nonisolatedScoped(SessionScope.self, Session.self) { _ in Session() }
                scoped(SessionScope.self, Service.self) { (config: Config, session: Session) in
                    creations.increment()
                    return Service(config: config, session: session)
                }
                scoped(Service.self, scope: SessionScope.self, qualifier: Flavor.special) { (config: Config, session: Session) in
                    Service(config: config, session: session)
                }
            }
        }
        let first = try application.createScope(SessionScope.self, id: 1)
        let second = try application.createScope(SessionScope.self, id: 2)

        let service = try first.get(Service.self, qualifier: nil)
        let cached = try first.get(Service.self, qualifier: nil)
        let other = try second.get(Service.self, qualifier: nil)
        let special = try first.get(Service.self, qualifier: Flavor.special)

        XCTAssertTrue(service === cached)
        XCTAssertFalse(service === other)
        XCTAssertTrue(service.session === (try first.nonisolatedGet(Session.self)))
        XCTAssertTrue(special.session === service.session)
        XCTAssertEqual(service.config.name, "config")
        XCTAssertEqual(creations.value, 2)
    }

    // swiftformat:disable:next redundantAsync
    func testNonisolatedScopedConstructorResolvesDependenciesFromTheScopeInBothArgumentOrders() async throws {
        let application = try SkeinApplication {
            module {
                nonisolatedInstance(Config(name: "config"))
                nonisolatedScoped(SessionScope.self, Session.self) { _ in Session() }
                nonisolatedScoped(SessionScope.self, Service.self) { (config: Config, session: Session) in
                    Service(config: config, session: session)
                }
                nonisolatedScoped(Service.self, scope: SessionScope.self, qualifier: Flavor.special) { (config: Config, session: Session) in
                    Service(config: config, session: session)
                }
            }
        }
        let scope = try application.createScope(SessionScope.self, id: 1)

        let service = try scope.nonisolatedGet(Service.self)
        let special = try scope.nonisolatedGet(Service.self, qualifier: Flavor.special)

        XCTAssertTrue(service === (try scope.nonisolatedGet(Service.self)))
        XCTAssertTrue(service.session === (try scope.nonisolatedGet(Session.self)))
        XCTAssertTrue(special.session === service.session)
        XCTAssertFalse(special === service)
    }

    func testActorScopedConstructorResolvesDependenciesFromTheScopeInBothArgumentOrders() async throws {
        let application = try SkeinApplication {
            module {
                nonisolatedInstance(Config(name: "config"))
                nonisolatedScoped(SessionScope.self, Session.self) { _ in Session() }
                actorScoped(SessionScope.self, Service.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor (config: Config, session: Session) in
                    Service(config: config, session: session)
                }
                actorScoped(Service.self, scope: SessionScope.self, isolatedTo: LifecycleTestActor.self, qualifier: Flavor.special) { @LifecycleTestActor (config: Config, session: Session) in
                    Service(config: config, session: session)
                }
            }
        }
        let scope = try application.createScope(SessionScope.self, id: 1)

        let service = try await scope.actorGet(Service.self)
        let cached = try await scope.actorGet(Service.self)
        let special = try await scope.actorGet(Service.self, qualifier: Flavor.special)

        XCTAssertTrue(service === cached)
        XCTAssertTrue(service.session === (try scope.nonisolatedGet(Session.self)))
        XCTAssertTrue(special.session === service.session)
        await scope.close()
    }

    func testScopedConstructorsRunTheirDisposersWhenTheScopeCloses() async throws {
        let disposals = LifecycleTestRecorder()
        let application = try SkeinApplication {
            module {
                scoped(SessionScope.self, Config.self, onClose: { _ in await disposals.append("main") }, using: {
                    Config(name: "main")
                })
                nonisolatedScoped(SessionScope.self, Session.self, onClose: { _ in await disposals.append("nonisolated") }, using: {
                    Session()
                })
                actorScoped(
                    SessionScope.self,
                    Service.self,
                    isolatedTo: LifecycleTestActor.self,
                    onClose: { @LifecycleTestActor _ in await disposals.append("actor") },
                    using: { @LifecycleTestActor (config: Config, session: Session) in
                        Service(config: config, session: session)
                    }
                )
            }
        }
        let scope = try application.createScope(SessionScope.self, id: 1)
        _ = try await scope.actorGet(Service.self)

        await scope.close()

        let values = await disposals.values
        XCTAssertEqual(values, ["actor", "nonisolated", "main"])
    }

    // MARK: Validation

    func testScopeRootBuiltFromConstructorFailsWhenADependencyIsMissing() async throws {
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                module {
                    nonisolatedInstance(Config(name: "config"))
                    scoped(SessionScope.self, Service.self) { (config: Config, session: Session) in
                        Service(config: config, session: session)
                    }.root()
                }
            }
            XCTFail("Expected validated startup to fail")
        } catch {
            guard case let .missingBinding(type, _, _) = error as? GraphValidationError else {
                return XCTFail("Expected missingBinding, got \(error)")
            }
            XCTAssertEqual(type, String(reflecting: Session.self))
        }
    }

    func testScopeRootBuiltFromConstructorFailsOnACrossScopeDependency() async throws {
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                module {
                    nonisolatedInstance(Config(name: "config"))
                    nonisolatedScoped(RequestScope.self, Session.self) { _ in Session() }
                    nonisolatedScoped(SessionScope.self, Service.self) { (config: Config, session: Session) in
                        Service(config: config, session: session)
                    }.root()
                }
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

    func testScopeRootBuiltFromConstructorFailsOnAnIsolationMismatch() async throws {
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                module {
                    nonisolatedInstance(Config(name: "config"))
                    scoped(SessionScope.self, Session.self) { _ in Session() }
                    nonisolatedScoped(SessionScope.self, Service.self) { (config: Config, session: Session) in
                        Service(config: config, session: session)
                    }.root()
                }
            }
            XCTFail("Expected validated startup to fail")
        } catch {
            guard case .isolationMismatch = error as? GraphValidationError else {
                return XCTFail("Expected isolationMismatch, got \(error)")
            }
        }
    }

    func testValidScopeRootsBuiltFromConstructorsRunNoProviderAndAreFullyTraversed() async throws {
        let application = try await SkeinApplication(validation: .declaredRoots) {
            module {
                nonisolatedInstance(Config(name: "config"))
                nonisolatedScoped(SessionScope.self, Session.self) { () -> Session in
                    XCTFail("Structural validation must not execute providers")
                    return Session()
                }
                scoped(SessionScope.self, Service.self) { (config: Config, session: Session) -> Service in
                    XCTFail("Structural validation must not execute providers")
                    return Service(config: config, session: session)
                }.root()
                nonisolatedScoped(SessionScope.self, Service.self, qualifier: Flavor.special) { (config: Config, session: Session) -> Service in
                    XCTFail("Structural validation must not execute providers")
                    return Service(config: config, session: session)
                }.root()
                actorScoped(RequestScope.self, Service.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor (config: Config) -> Service in
                    XCTFail("Structural validation must not execute providers")
                    return Service(config: config, session: Session())
                }.root()
            }
        }

        XCTAssertEqual(try XCTUnwrap(application.startupValidationReport).opaqueBindings, [])
        await application.close()
    }
}
