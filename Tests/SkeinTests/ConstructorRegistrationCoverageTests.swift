import Skein
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
@MainActor final class ConstructorRegistrationCoverageTests: XCTestCase {
    private struct Config: Sendable {
        let name: String
    }

    private struct Clock: Sendable {
        let tick: Int
    }

    private final class Service: Sendable {
        let config: Config
        let clock: Clock

        init(config: Config, clock: Clock) {
            self.config = config
            self.clock = clock
        }
    }

    private struct Assisted: Sendable {
        let id: Int
        let config: Config
        let clock: Clock
    }

    private let dependencies = module {
        nonisolatedInstance(Config(name: "config"))
        nonisolatedInstance(Clock(tick: 1))
    }

    func testNonisolatedSingleConstructorResolvesDependenciesOnce() throws {
        let constructions = LockedCounter()
        let application = try SkeinApplication {
            dependencies
            module {
                nonisolatedSingle(Service.self) { (config: Config, clock: Clock) in
                    constructions.increment()
                    return Service(config: config, clock: clock)
                }
            }
        }

        let first = try application.nonisolatedGet(Service.self)
        let second = try application.nonisolatedGet(Service.self)

        XCTAssertTrue(first === second)
        XCTAssertEqual(first.config.name, "config")
        XCTAssertEqual(first.clock.tick, 1)
        XCTAssertEqual(constructions.value, 1)
    }

    func testNonisolatedAssistedFactoryConstructorPassesArgumentsAndDependencies() throws {
        let application = try SkeinApplication {
            dependencies
            module {
                nonisolatedFactory(Assisted.self, arguments: Int.self, using: Assisted.init)
            }
        }

        let assisted = try application.nonisolatedGet(Assisted.self, arguments: 7)

        XCTAssertEqual(assisted.id, 7)
        XCTAssertEqual(assisted.config.name, "config")
        XCTAssertEqual(assisted.clock.tick, 1)
    }

    func testActorSingleConstructorResolvesDependenciesOnItsActor() async throws {
        let constructions = LockedCounter()
        let application = try SkeinApplication {
            dependencies
            module {
                actorSingle(Service.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor (config: Config, clock: Clock) in
                    constructions.increment()
                    return Service(config: config, clock: clock)
                }
            }
        }

        let first = try await application.actorGet(Service.self)
        let second = try await application.actorGet(Service.self)

        XCTAssertTrue(first === second)
        XCTAssertEqual(first.config.name, "config")
        XCTAssertEqual(constructions.value, 1)
    }

    func testActorAssistedFactoryConstructorPassesArgumentsAndDependencies() async throws {
        let application = try SkeinApplication {
            dependencies
            module {
                actorFactory(
                    Assisted.self,
                    arguments: Int.self,
                    isolatedTo: LifecycleTestActor.self
                ) { @LifecycleTestActor (id: Int, config: Config, clock: Clock) in
                    Assisted(id: id, config: config, clock: clock)
                }
            }
        }

        let assisted = try await application.actorGet(Assisted.self, arguments: 9)

        XCTAssertEqual(assisted.id, 9)
        XCTAssertEqual(assisted.config.name, "config")
        XCTAssertEqual(assisted.clock.tick, 1)
    }

    func testConstructorVariantsRecordEveryDependencyEdge() throws {
        let variants: [(name: String, root: @MainActor () -> Binding, service: String)] = [
            ("nonisolatedSingle", {
                nonisolatedSingle(Service.self) { (config: Config, clock: Clock) in Service(config: config, clock: clock) }.root()
            }, BindingKey(Service.self, qualifier: nil).description),
            ("nonisolatedFactory(arguments:)", {
                nonisolatedFactory(Assisted.self, arguments: Int.self, using: Assisted.init).root()
            }, BindingKey(Assisted.self, qualifier: nil, argumentType: Int.self).description),
            ("actorSingle", {
                actorSingle(Service.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor (config: Config, clock: Clock) in
                    Service(config: config, clock: clock)
                }.root()
            }, BindingKey(Service.self, qualifier: nil).description),
            ("actorFactory(arguments:)", {
                actorFactory(Assisted.self, arguments: Int.self, isolatedTo: LifecycleTestActor.self) { @LifecycleTestActor (id: Int, config: Config, clock: Clock) in
                    Assisted(id: id, config: config, clock: clock)
                }.root()
            }, BindingKey(Assisted.self, qualifier: nil, argumentType: Int.self).description)
        ]

        for variant in variants {
            let withoutDependencies = try SkeinApplication { module { variant.root() } }
            assertMissing(Config.self, from: variant.service, in: withoutDependencies, variant: variant.name)

            let withConfig = try SkeinApplication {
                module {
                    variant.root()
                    nonisolatedInstance(Config(name: "config"))
                }
            }
            assertMissing(Clock.self, from: variant.service, in: withConfig, variant: variant.name)

            let complete = try SkeinApplication {
                dependencies
                module { variant.root() }
            }
            XCTAssertEqual(try complete.validateGraph().opaqueBindings, [], variant.name)
        }
    }

    private func assertMissing(
        _ dependency: (some Any).Type,
        from service: String,
        in application: SkeinApplication,
        variant: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try application.validateGraph(), variant, file: file, line: line) { error in
            guard case let .missingBinding(type, _, path) = error as? GraphValidationError else {
                return XCTFail("\(variant): expected missingBinding, got \(error)", file: file, line: line)
            }
            XCTAssertEqual(type, String(reflecting: dependency), variant, file: file, line: line)
            XCTAssertEqual(path, [service, BindingKey(dependency, qualifier: nil).description], variant, file: file, line: line)
        }
    }
}
