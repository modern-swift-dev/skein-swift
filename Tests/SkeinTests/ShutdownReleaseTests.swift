import Skein
import XCTest

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
@MainActor final class ShutdownReleaseTests: XCTestCase {
    private final class FirstService: Sendable {}
    private final class SecondService: Sendable {}

    private enum CacheKind {
        case root
        case scope
        case actorRoot
        case actorScope
    }

    @MainActor private final class References {
        weak var second: SecondService?
        var firstDisposals = 0
        var secondDisposals = 0

        func recordSecondDisposal() {
            secondDisposals += 1
        }

        func assertSecondReleased() {
            firstDisposals += 1
            XCTAssertEqual(secondDisposals, 1)
            XCTAssertNil(second, "A disposed service should be released before the next disposer runs")
        }
    }

    func testRootShutdownReleasesEachServiceBeforeDisposingTheNext() async throws {
        try await assertRelease(for: .root)
    }

    func testScopeShutdownReleasesEachServiceBeforeDisposingTheNext() async throws {
        try await assertRelease(for: .scope)
    }

    func testActorRootShutdownReleasesEachServiceBeforeDisposingTheNext() async throws {
        try await assertRelease(for: .actorRoot)
    }

    func testActorScopeShutdownReleasesEachServiceBeforeDisposingTheNext() async throws {
        try await assertRelease(for: .actorScope)
    }

    private func assertRelease(for kind: CacheKind) async throws {
        let references = References()
        let application = try SkeinApplication {
            module {
                switch kind {
                    case .root:
                        single(
                            FirstService.self,
                            onClose: { _ in references.assertSecondReleased() },
                            provider: { _ in FirstService() }
                        )
                        single(
                            SecondService.self,
                            onClose: { _ in references.recordSecondDisposal() },
                            provider: { _ in SecondService() }
                        )
                    case .scope:
                        scoped(
                            SeededScope.self,
                            FirstService.self,
                            onClose: { _ in references.assertSecondReleased() },
                            provider: { _ in FirstService() }
                        )
                        scoped(
                            SeededScope.self,
                            SecondService.self,
                            onClose: { _ in references.recordSecondDisposal() },
                            provider: { _ in SecondService() }
                        )
                    case .actorRoot:
                        actorSingle(
                            FirstService.self,
                            isolatedTo: LifecycleTestActor.self,
                            onClose: { @LifecycleTestActor _ in await references.assertSecondReleased() },
                            provider: { @LifecycleTestActor _ in FirstService() }
                        )
                        actorSingle(
                            SecondService.self,
                            isolatedTo: LifecycleTestActor.self,
                            onClose: { @LifecycleTestActor _ in await references.recordSecondDisposal() },
                            provider: { @LifecycleTestActor _ in SecondService() }
                        )
                    case .actorScope:
                        actorScoped(
                            FirstService.self,
                            scope: SeededScope.self,
                            isolatedTo: LifecycleTestActor.self,
                            onClose: { @LifecycleTestActor _ in await references.assertSecondReleased() },
                            provider: { @LifecycleTestActor _ in FirstService() }
                        )
                        actorScoped(
                            SecondService.self,
                            scope: SeededScope.self,
                            isolatedTo: LifecycleTestActor.self,
                            onClose: { @LifecycleTestActor _ in await references.recordSecondDisposal() },
                            provider: { @LifecycleTestActor _ in SecondService() }
                        )
                }
            }
        }

        let resolver: any Resolver = switch kind {
            case .root,
                 .actorRoot:
                application
            case .scope,
                 .actorScope:
                try application.createScope(SeededScope.self, id: "release")
        }
        switch kind {
            case .root,
                 .scope:
                _ = try resolver.get(FirstService.self)
                references.second = try resolver.get(SecondService.self)
            case .actorRoot,
                 .actorScope:
                _ = try await resolver.actorGet(FirstService.self)
                references.second = try await resolver.actorGet(SecondService.self)
        }
        XCTAssertNotNil(references.second)

        await application.close()

        XCTAssertEqual(references.firstDisposals, 1)
        XCTAssertNil(references.second)
    }
}
