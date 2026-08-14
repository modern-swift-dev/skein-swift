import Foundation
@testable import Skein
import XCTest

private func ergonomicUnderlyingSkeinError(_ error: any Error) -> SkeinError? {
    if let resolution = error as? SkeinResolutionError {
        return resolution.underlying as? SkeinError
    }
    return error as? SkeinError
}

private final class ErgonomicReference: @unchecked Sendable {
    let value: String
    init(_ value: String = "root") {
        self.value = value
    }
}

private struct UserScope: SkeinScope {}
private struct SessionScope: SkeinScope {}

private actor DisposalLog {
    private var entries: [String] = []
    func append(_ entry: String) {
        entries.append(entry)
    }

    func snapshot() -> [String] {
        entries
    }
}

private final class ApplicationBox: @unchecked Sendable {
    var application: SkeinApplication?
}

private final class ScopeBox: @unchecked Sendable {
    var scope: SkeinScopeInstance<UserScope>?
}

@MainActor private final class ErgonomicMainActorValue {}

@MainActor private final class MainActorCloseGate {
    private(set) var entered = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        entered = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

final class ErgonomicsTests: XCTestCase {
    func testApplicationsOwnIndependentSingletonCaches() throws {
        let definitions = module {
            single(ErgonomicReference.self) { _ in ErgonomicReference() }
        }
        let first = try SkeinApplication { modules(definitions) }
        let second = try SkeinApplication { modules(definitions) }

        let firstValue: ErgonomicReference = try first.get()
        let sameFirstValue: ErgonomicReference = try first.get()
        let secondValue: ErgonomicReference = try second.get()

        XCTAssertTrue(firstValue === sameFirstValue)
        XCTAssertFalse(firstValue === secondValue)
    }

    func testNestedResolutionAcrossApplicationsDoesNotCreateFalseCycle() throws {
        let second = try SkeinApplication {
            modules(module { factory(String.self) { _ in "second" } })
        }
        let first = try SkeinApplication {
            modules(module {
                factory(String.self) { _ in "first:\(try second.get(String.self))" }
            })
        }

        XCTAssertEqual(try first.get(String.self), "first:second")
    }

    func testAssistedFactoriesCoexistByArgumentType() throws {
        let application = try SkeinApplication {
            modules(module {
                factory(String.self, arguments: Int.self) { _, value in "int:\(value)" }
                factory(String.self, arguments: Bool.self) { _, value in "bool:\(value)" }
                factory(String.self) { _ in "ordinary" }
            })
        }

        XCTAssertEqual(try application.get(String.self), "ordinary")
        XCTAssertEqual(try application.get(String.self, arguments: 7), "int:7")
        XCTAssertEqual(try application.get(String.self, arguments: true), "bool:true")
    }

    func testScopeShadowsRootCachesPerScopeAndSharesRootSingletons() throws {
        let application = try SkeinApplication {
            modules(module {
                single(String.self) { _ in "root" }
                single(ErgonomicReference.self) { _ in ErgonomicReference() }
                scoped(UserScope.self, String.self) { _ in UUID().uuidString }
            })
        }
        let first = try application.createScope(UserScope.self, id: "first")
        let second = try application.createScope(UserScope.self, id: "second")

        let firstString: String = try first.get()
        XCTAssertEqual(try first.get(String.self), firstString)
        XCTAssertNotEqual(try second.get(String.self), firstString)
        XCTAssertEqual(try application.get(String.self), "root")

        let firstRoot: ErgonomicReference = try first.get()
        let secondRoot: ErgonomicReference = try second.get()
        XCTAssertTrue(firstRoot === secondRoot)
    }

    func testScopedInstanceIsCreatedOnceUnderConcurrentResolution() throws {
        let constructions = LockedCounter()
        let failures = LockedCounter()
        let application = try SkeinApplication {
            modules(module {
                scoped(UserScope.self, ErgonomicReference.self) { _ in
                    constructions.increment()
                    return ErgonomicReference()
                }
            })
        }
        let scope = try application.createScope(UserScope.self, id: "concurrent")

        DispatchQueue.concurrentPerform(iterations: 64) { _ in
            do {
                let _: ErgonomicReference = try scope.get()
            } catch {
                failures.increment()
            }
        }

        XCTAssertEqual(constructions.value, 1)
        XCTAssertEqual(failures.value, 0)
    }

    func testScopeKindsHaveIndependentBindingsAndDuplicateActiveIDsAreRejected() async throws {
        let application = try SkeinApplication {
            modules(module {
                scoped(UserScope.self, String.self) { _ in "user" }
                scoped(SessionScope.self, String.self) { _ in "session" }
            })
        }
        let user = try application.createScope(UserScope.self, id: 1)
        let session = try application.createScope(SessionScope.self, id: 1)
        XCTAssertEqual(try user.get(String.self), "user")
        XCTAssertEqual(try session.get(String.self), "session")

        XCTAssertThrowsError(try application.createScope(UserScope.self, id: 1)) { error in
            guard case .duplicateScope = error as? SkeinError else {
                return XCTFail("Expected duplicateScope, got \(error)")
            }
        }
        await user.close()
        let replacement = try application.createScope(UserScope.self, id: 1)
        XCTAssertEqual(try replacement.get(String.self), "user")
    }

    func testCloseDisposesScopesBeforeSingletonsInReverseCreationOrder() async throws {
        let log = DisposalLog()
        let application = try SkeinApplication {
            modules(module {
                single(
                    String.self,
                    onClose: { _ in await log.append("root") },
                    provider: { _ in "root" }
                )
                scoped(
                    UserScope.self,
                    ErgonomicReference.self,
                    onClose: { value in await log.append(value.value) },
                    provider: { _ in ErgonomicReference("scope") }
                )
            })
        }
        let scope = try application.createScope(UserScope.self, id: "scope")
        let _: String = try application.get()
        let _: ErgonomicReference = try scope.get()

        await application.close()
        await application.close()

        let entries = await log.snapshot()
        XCTAssertEqual(entries, ["scope", "root"])
        XCTAssertThrowsError(try application.get(String.self)) { error in
            XCTAssertEqual(ergonomicUnderlyingSkeinError(error), .applicationClosed)
        }
        XCTAssertThrowsError(try scope.get(ErgonomicReference.self)) { error in
            guard case .applicationClosed = ergonomicUnderlyingSkeinError(error) else {
                return XCTFail("Expected applicationClosed, got \(error)")
            }
        }
    }

    func testDisposalMayReenterOwnerCloseWithoutDeadlocking() async throws {
        let applicationBox = ApplicationBox()
        let scopeBox = ScopeBox()
        let disposals = LockedCounter()
        let application = try SkeinApplication {
            modules(module {
                single(
                    String.self,
                    onClose: { _ in
                        await applicationBox.application?.close()
                        disposals.increment()
                    },
                    provider: { _ in "root" }
                )
                scoped(
                    UserScope.self,
                    ErgonomicReference.self,
                    onClose: { _ in
                        await scopeBox.scope?.close()
                        await applicationBox.application?.close()
                        disposals.increment()
                    },
                    provider: { _ in ErgonomicReference() }
                )
            })
        }
        applicationBox.application = application
        let scope = try application.createScope(UserScope.self, id: "reentrant")
        scopeBox.scope = scope
        let _: String = try application.get()
        let _: ErgonomicReference = try scope.get()

        await application.close()

        XCTAssertEqual(disposals.value, 2)
    }

    @MainActor func testMainActorAssistedFactoryRequiresMainActorResolution() async throws {
        let application = try SkeinApplication {
            modules(module {
                mainActorFactory(
                    ErgonomicMainActorValue.self,
                    arguments: String.self
                ) { _, _ in ErgonomicMainActorValue() }
            })
        }
        let _: ErgonomicMainActorValue = try application.mainActorGet(arguments: "value")

        let error = await Task.detached { () -> SkeinError? in
            do {
                let _: ErgonomicMainActorValue = try application.get(arguments: "value")
                return nil
            } catch {
                return ergonomicUnderlyingSkeinError(error)
            }
        }.value
        guard case .mainActorBindingRequiresMainActor? = error else {
            return XCTFail("Expected mainActorBindingRequiresMainActor")
        }
    }

    @MainActor func testSimultaneousMainActorClosesSuspendAndDisposeExactlyOnce() async throws {
        let gate = MainActorCloseGate()
        var disposalCount = 0
        let application = try SkeinApplication {
            modules(module {
                mainActorSingle(
                    ErgonomicMainActorValue.self,
                    onClose: { _ in
                        disposalCount += 1
                        await gate.wait()
                    },
                    provider: { _ in ErgonomicMainActorValue() }
                )
            })
        }
        let _: ErgonomicMainActorValue = try application.mainActorGet()

        let firstClose = Task { @MainActor in await application.close() }
        while !gate.entered {
            await Task.yield()
        }
        let secondClose = Task { @MainActor in await application.close() }
        await Task.yield()
        gate.release()

        await firstClose.value
        await secondClose.value
        XCTAssertEqual(disposalCount, 1)
    }
}
