import Skein
import XCTest

final class AsyncCachedResolutionTests: XCTestCase {
    private actor DeferredResolution {
        private(set) var task: Task<ConcurrentReference, Error>?

        func store(_ task: Task<ConcurrentReference, Error>) {
            self.task = task
        }
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @MainActor func testCompletedSingletonCanBeResolvedFromTaskInheritingItsCreationTrace() async throws {
        let gate = LifecycleTestGate()
        let deferredResolution = DeferredResolution()
        let creations = LockedCounter()
        let application = try SkeinApplication {
            module {
                actorSingle(
                    ConcurrentReference.self,
                    isolatedTo: LifecycleTestActor.self,
                    provider: { @LifecycleTestActor resolver in
                        creations.increment()
                        let task = Task {
                            await gate.wait()
                            return try await resolver.actorGet(ConcurrentReference.self)
                        }
                        await deferredResolution.store(task)
                        return ConcurrentReference()
                    }
                )
            }
        }

        let original = try await application.actorGet(ConcurrentReference.self)
        let pending = await deferredResolution.task
        let task = try XCTUnwrap(pending)
        await gate.open()
        do {
            let cached = try await task.value
            XCTAssertTrue(cached === original)
        } catch {
            XCTFail("Expected the completed singleton to bypass its inherited creation trace, got \(error)")
        }
        XCTAssertEqual(creations.value, 1)
        await application.close()
    }

    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @MainActor func testCompletedScopedServiceCanBeResolvedFromTaskInheritingItsCreationTrace() async throws {
        let gate = LifecycleTestGate()
        let deferredResolution = DeferredResolution()
        let creations = LockedCounter()
        let application = try SkeinApplication {
            module {
                actorScoped(
                    ConcurrentReference.self,
                    scope: SeededScope.self,
                    isolatedTo: LifecycleTestActor.self,
                    provider: { @LifecycleTestActor resolver in
                        creations.increment()
                        let task = Task {
                            await gate.wait()
                            return try await resolver.actorGet(ConcurrentReference.self)
                        }
                        await deferredResolution.store(task)
                        return ConcurrentReference()
                    }
                )
            }
        }
        let scope = try application.createScope(SeededScope.self, id: "deferred-resolution")

        let original = try await scope.actorGet(ConcurrentReference.self)
        let pending = await deferredResolution.task
        let task = try XCTUnwrap(pending)
        await gate.open()
        do {
            let cached = try await task.value
            XCTAssertTrue(cached === original)
        } catch {
            XCTFail("Expected the completed scoped service to bypass its inherited creation trace, got \(error)")
        }
        XCTAssertEqual(creations.value, 1)
        await application.close()
    }
}
