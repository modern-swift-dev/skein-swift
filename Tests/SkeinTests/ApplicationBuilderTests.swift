import Skein
import XCTest

@MainActor final class ApplicationBuilderTests: XCTestCase {
    private struct Mode: Sendable, Equatable {
        let name: String
    }

    // swiftformat:disable:next redundantAsync
    func testIfBlockIncludesModuleOnlyWhenConditionHolds() async throws {
        for include in [true, false] {
            let application = try SkeinApplication {
                module { nonisolatedInstance(Mode(name: "base")) }
                if include {
                    module { nonisolatedInstance(1) }
                }
            }

            XCTAssertEqual(try application.nonisolatedGet(Mode.self), Mode(name: "base"))
            if include {
                XCTAssertEqual(try application.nonisolatedGet(Int.self), 1)
            } else {
                XCTAssertThrowsError(try application.nonisolatedGet(Int.self))
            }
        }
    }

    // swiftformat:disable:next redundantAsync
    func testIfElseBlockSelectsOneBranch() async throws {
        for useFirst in [true, false] {
            let application = try SkeinApplication {
                if useFirst {
                    module { nonisolatedInstance(Mode(name: "first")) }
                } else {
                    module { nonisolatedInstance(Mode(name: "second")) }
                }
            }

            XCTAssertEqual(try application.nonisolatedGet(Mode.self), Mode(name: useFirst ? "first" : "second"))
        }
    }

    // swiftformat:disable:next redundantAsync
    func testOptionalModuleIsIncludedOnlyWhenPresent() async throws {
        let modules: [Module?] = [module { nonisolatedInstance(Mode(name: "optional")) }, nil]
        for optional in modules {
            let application = try SkeinApplication {
                if let optional {
                    optional
                }
            }

            if optional == nil {
                XCTAssertThrowsError(try application.nonisolatedGet(Mode.self))
            } else {
                XCTAssertEqual(try application.nonisolatedGet(Mode.self), Mode(name: "optional"))
            }
        }
    }
}
