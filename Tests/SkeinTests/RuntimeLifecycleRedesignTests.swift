import XCTest
@testable import Skein

@globalActor
private actor RuntimeTestActor {
    static let shared = RuntimeTestActor()
}

@RuntimeTestActor
private final class RuntimeActorValue: @unchecked Sendable {
    static var creations = 0
    init() { Self.creations += 1 }
}

private struct RuntimeCycleA: Sendable {}
private struct RuntimeCycleB: Sendable {}
private enum RuntimeScope: SkeinScope {}

@globalActor
private actor RuntimeOtherActor {
    static let shared = RuntimeOtherActor()
}

private actor RuntimeGate {
    private var isOpen = false
    private var arrivals = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        arrivals += 1
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func waitForArrivals(_ expected: Int) async {
        while arrivals < expected { await Task.yield() }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

private actor RuntimeRecorder {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

private actor RuntimeSkeinErrorRecorder {
    private(set) var values: [SkeinError] = []
    func append(_ value: SkeinError) { values.append(value) }
}

private final class RuntimeLockedLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ value: String) { lock.withLock { storage.append(value) } }
    var values: [String] { lock.withLock { storage } }
}

private final class RuntimeLockedCount: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    func increment() { lock.withLock { storage += 1 } }
    var value: Int { lock.withLock { storage } }
}

private struct RuntimeRetryValue: Sendable {}

@RuntimeTestActor
private final class RuntimeRetryState: @unchecked Sendable {
    private(set) var attempts = 0

    func make() throws -> RuntimeRetryValue {
        attempts += 1
        if attempts == 1 { throw RuntimeTestFailure.expected }
        return RuntimeRetryValue()
    }
}

private enum RuntimeTestFailure: Error { case expected }
private final class RuntimeCancelledValue: @unchecked Sendable {}
private final class RuntimeCloseRootValue: @unchecked Sendable {}
private final class RuntimeCloseScopeValue: @unchecked Sendable {}
private final class RuntimeCompletionA: @unchecked Sendable {}
private final class RuntimeCompletionB: @unchecked Sendable {}
private struct RuntimeRootSentinel: Sendable {}
private enum RuntimeClosingScope: SkeinScope {}
private struct RuntimeMissingDependency {}
private struct RuntimeNeedsMissing {
    init(_ dependency: RuntimeMissingDependency) {}
}
private struct RuntimeEagerMain {}
private struct RuntimeEagerActor: Sendable {}
private struct RuntimeEagerNonisolated: Sendable {}
private struct RuntimeStartupValue: Sendable {}
private struct RuntimeIndependentRootA: Sendable {}
private struct RuntimeIndependentRootB: Sendable {}
private struct RuntimeIndependentScopeA: Sendable {}
private struct RuntimeIndependentScopeB: Sendable {}
private enum RuntimeIndependentCycleScope: SkeinScope {}

final class RuntimeLifecycleRedesignTests: XCTestCase {
    @MainActor
    func testMainActorGetAcceptsMainActorAndNonisolatedBindings() throws {
        let application = try SkeinApplication {
            module {
                instance("main")
                nonisolatedInstance(42)
            }
        }

        let main: String = try application.get()
        let transferable: Int = try application.get()
        XCTAssertEqual(main, "main")
        XCTAssertEqual(transferable, 42)

        XCTAssertThrowsError(try application.nonisolatedGet(String.self)) { error in
            guard let resolution = error as? SkeinResolutionError,
                  case .bindingIsolationMismatch = resolution.underlying as? SkeinError else {
                return XCTFail("Expected an isolation mismatch, got \(error)")
            }
        }
    }

    @MainActor
    func testActorGetResolvesEveryIsolationKindAndCoalescesCustomSingle() async throws {
        let initialCreations = await RuntimeActorValue.creations
        let application = try SkeinApplication {
            module {
                instance("main")
                nonisolatedInstance(42)
                actorSingle(
                    RuntimeActorValue.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor _ in RuntimeActorValue() }
                )
            }
        }

        let main: String = try await application.actorGet()
        let transferable: Int = try await application.actorGet()
        XCTAssertEqual(main, "main")
        XCTAssertEqual(transferable, 42)

        let identities = try await withThrowingTaskGroup(
            of: ObjectIdentifier.self,
            returning: [ObjectIdentifier].self
        ) { group in
            for _ in 0..<20 {
                group.addTask {
                    let value: RuntimeActorValue = try await application.actorGet()
                    return ObjectIdentifier(value)
                }
            }
            var values: [ObjectIdentifier] = []
            for try await value in group { values.append(value) }
            return values
        }
        XCTAssertEqual(Set(identities).count, 1)
        let finalCreations = await RuntimeActorValue.creations
        XCTAssertEqual(finalCreations, initialCreations + 1)
    }

    @MainActor
    func testTaskLocalCycleDetectionCrossesCustomActorTasks() async throws {
        let application = try SkeinApplication {
            module {
                actorSingle(
                    RuntimeCycleA.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor resolver in
                        let _: RuntimeCycleB = try await resolver.actorGet()
                        return RuntimeCycleA()
                    }
                )
                actorSingle(
                    RuntimeCycleB.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor resolver in
                        let _: RuntimeCycleA = try await resolver.actorGet()
                        return RuntimeCycleB()
                    }
                )
            }
        }

        do {
            let _: RuntimeCycleA = try await application.actorGet()
            XCTFail("Expected a circular dependency")
        } catch let error as SkeinResolutionError {
            guard case let .circularDependency(path) = error.underlying as? SkeinError else {
                return XCTFail("Expected a circular dependency, got \(error.underlying)")
            }
            XCTAssertEqual(path.count, 3)
        }
    }

    @MainActor
    func testIndependentlyStartedCustomRootCyclesFailInsteadOfDeadlocking() async throws {
        let gateA = RuntimeGate()
        let gateB = RuntimeGate()
        let errors = RuntimeSkeinErrorRecorder()
        let application = try SkeinApplication {
            module {
                actorSingle(
                    RuntimeIndependentRootA.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor resolver in
                        await gateA.wait()
                        let _: RuntimeIndependentRootB = try await resolver.actorGet()
                        return RuntimeIndependentRootA()
                    }
                )
                actorSingle(
                    RuntimeIndependentRootB.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor resolver in
                        await gateB.wait()
                        let _: RuntimeIndependentRootA = try await resolver.actorGet()
                        return RuntimeIndependentRootB()
                    }
                )
            }
        }

        let completed = expectation(description: "both root resolutions finish")
        completed.expectedFulfillmentCount = 2
        let resolvingA = Task {
            defer { completed.fulfill() }
            do { let _: RuntimeIndependentRootA = try await application.actorGet() }
            catch { await recordSkeinError(error, in: errors) }
        }
        let resolvingB = Task {
            defer { completed.fulfill() }
            do { let _: RuntimeIndependentRootB = try await application.actorGet() }
            catch { await recordSkeinError(error, in: errors) }
        }
        defer { resolvingA.cancel(); resolvingB.cancel() }

        await gateA.waitForArrivals(1)
        await gateB.waitForArrivals(1)
        await gateA.open()
        await gateB.open()
        await fulfillment(of: [completed], timeout: 2)

        let recorded = await errors.values
        XCTAssertEqual(recorded.count, 2)
        XCTAssertTrue(recorded.allSatisfy {
            if case .circularDependency = $0 { return true }
            return false
        })
    }

    @MainActor
    func testIndependentlyStartedCustomScopedCyclesFailInsteadOfDeadlocking() async throws {
        let gateA = RuntimeGate()
        let gateB = RuntimeGate()
        let errors = RuntimeSkeinErrorRecorder()
        let application = try SkeinApplication {
            module {
                actorScoped(
                    RuntimeIndependentScopeA.self,
                    scope: RuntimeIndependentCycleScope.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor resolver in
                        await gateA.wait()
                        let _: RuntimeIndependentScopeB = try await resolver.actorGet()
                        return RuntimeIndependentScopeA()
                    }
                )
                actorScoped(
                    RuntimeIndependentScopeB.self,
                    scope: RuntimeIndependentCycleScope.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor resolver in
                        await gateB.wait()
                        let _: RuntimeIndependentScopeA = try await resolver.actorGet()
                        return RuntimeIndependentScopeB()
                    }
                )
            }
        }
        let scope = try application.createScope(RuntimeIndependentCycleScope.self, id: "cycle")

        let completed = expectation(description: "both scoped resolutions finish")
        completed.expectedFulfillmentCount = 2
        let resolvingA = Task {
            defer { completed.fulfill() }
            do { let _: RuntimeIndependentScopeA = try await scope.actorGet() }
            catch { await recordSkeinError(error, in: errors) }
        }
        let resolvingB = Task {
            defer { completed.fulfill() }
            do { let _: RuntimeIndependentScopeB = try await scope.actorGet() }
            catch { await recordSkeinError(error, in: errors) }
        }
        defer { resolvingA.cancel(); resolvingB.cancel() }

        await gateA.waitForArrivals(1)
        await gateB.waitForArrivals(1)
        await gateA.open()
        await gateB.open()
        await fulfillment(of: [completed], timeout: 2)

        let recorded = await errors.values
        XCTAssertEqual(recorded.count, 2)
        XCTAssertTrue(recorded.allSatisfy {
            if case .circularDependency = $0 { return true }
            return false
        })
    }

    @MainActor
    func testDeclaredRootsValidateBeforeEagerExecution() async throws {
        var eagerCreations = 0
        let application = try await SkeinApplication(validation: .declaredRoots) {
            module {
                single(Int.self, provider: { _ in
                    eagerCreations += 1
                    return 7
                }).root(.eager)
                factory(String.self, provider: { _ in "opaque" }).root()
            }
        }

        XCTAssertEqual(eagerCreations, 1)
        XCTAssertEqual(application.startupValidationReport?.opaqueBindings.count, 2)
        let first: Int = try application.get()
        XCTAssertEqual(first, 7)
        XCTAssertEqual(eagerCreations, 1)
    }

    @MainActor
    func testFailedValidatedGlobalStartupCanBeRetried() async throws {
        stopSkein()
        defer { stopSkein() }

        do {
            _ = try await startSkeinIfNeeded(validation: .declaredRoots) {
                module {
                    actorSingle(
                        Int.self,
                        isolatedTo: RuntimeTestActor.self,
                        provider: { _ in 1 }
                    ).root()
                }
            }
            XCTFail("Expected dynamic actor isolation validation to fail")
        } catch {
            XCTAssertFalse(isSkeinStarted)
        }

        let started = try await startSkeinIfNeeded(validation: .declaredRoots) {
            module { instance(7).root() }
        }
        XCTAssertTrue(started)
        XCTAssertTrue(isSkeinStarted)
        XCTAssertNotNil(currentSkeinValidationReport)
    }

    @MainActor
    func testCustomActorScopedBindingCachesAndRejectsAfterClose() async throws {
        let application = try SkeinApplication {
            module {
                actorScoped(
                    RuntimeActorValue.self,
                    scope: RuntimeScope.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor _ in RuntimeActorValue() }
                )
            }
        }
        let scope = try application.createScope(RuntimeScope.self, id: "test")
        let first: RuntimeActorValue = try await scope.actorGet()
        let second: RuntimeActorValue = try await scope.actorGet()
        XCTAssertEqual(ObjectIdentifier(first), ObjectIdentifier(second))

        await scope.close()
        do {
            let _: RuntimeActorValue = try await scope.actorGet()
            XCTFail("Expected the scope to be closed")
        } catch let error as SkeinResolutionError {
            guard case .scopeClosed = error.underlying as? SkeinError else {
                return XCTFail("Expected scopeClosed, got \(error.underlying)")
            }
        }
    }

    @MainActor
    func testCustomActorSingletonRetriesAfterProviderFailure() async throws {
        let state = RuntimeRetryState()
        let application = try SkeinApplication {
            module {
                actorSingle(
                    RuntimeRetryValue.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor _ in try state.make() }
                )
            }
        }

        do {
            let _: RuntimeRetryValue = try await application.actorGet()
            XCTFail("Expected the first provider attempt to fail")
        } catch let error as SkeinResolutionError {
            XCTAssertTrue(error.underlying is RuntimeTestFailure)
        }

        let _: RuntimeRetryValue = try await application.actorGet()
        let attempts = await state.attempts
        XCTAssertEqual(attempts, 2)
    }

    @MainActor
    func testCancellingOneWaiterDoesNotCancelSharedSingletonCreation() async throws {
        let gate = RuntimeGate()
        let creations = RuntimeLockedCount()
        let application = try SkeinApplication {
            module {
                actorSingle(
                    RuntimeCancelledValue.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor _ in
                        creations.increment()
                        await gate.wait()
                        return RuntimeCancelledValue()
                    }
                )
            }
        }

        let cancelledWaiter = Task { try await application.actorGet(RuntimeCancelledValue.self) }
        await gate.waitForArrivals(1)
        let survivingWaiter = Task { try await application.actorGet(RuntimeCancelledValue.self) }
        for _ in 0..<10 { await Task.yield() }
        cancelledWaiter.cancel()
        await gate.open()

        let survivor = try await survivingWaiter.value
        _ = try? await cancelledWaiter.value
        let cached: RuntimeCancelledValue = try await application.actorGet()
        XCTAssertEqual(ObjectIdentifier(survivor), ObjectIdentifier(cached))
        XCTAssertEqual(creations.value, 1)
    }

    @MainActor
    func testCloseDuringRootCreationDisposesOnceAndRejectsWaiters() async throws {
        let gate = RuntimeGate()
        let disposals = RuntimeRecorder()
        let application = try SkeinApplication {
            module {
                nonisolatedInstance(RuntimeRootSentinel())
                actorSingle(
                    RuntimeCloseRootValue.self,
                    isolatedTo: RuntimeTestActor.self,
                    onClose: { @RuntimeTestActor _ in await disposals.append("root") },
                    provider: { @RuntimeTestActor _ in
                        await gate.wait()
                        return RuntimeCloseRootValue()
                    }
                )
            }
        }

        let first = Task { try await application.actorGet(RuntimeCloseRootValue.self) }
        await gate.waitForArrivals(1)
        let second = Task { try await application.actorGet(RuntimeCloseRootValue.self) }
        let close = Task { await application.close() }
        let applicationClosed = await waitUntilApplicationIsClosed(application)
        XCTAssertTrue(applicationClosed)
        await gate.open()

        for waiter in [first, second] {
            do {
                _ = try await waiter.value
                XCTFail("Expected resolution completing during close to fail")
            } catch {
                XCTAssertTrue(hasUnderlying(error, matching: .applicationClosed))
            }
        }
        await close.value
        let values = await disposals.values
        XCTAssertEqual(values, ["root"])
    }

    @MainActor
    func testCloseDuringScopeCreationDisposesOnceAndRejectsWaiters() async throws {
        let gate = RuntimeGate()
        let disposals = RuntimeRecorder()
        let application = try SkeinApplication {
            module {
                nonisolatedScoped(
                    RuntimeRootSentinel.self,
                    scope: RuntimeClosingScope.self,
                    provider: { _ in RuntimeRootSentinel() }
                )
                actorScoped(
                    RuntimeCloseScopeValue.self,
                    scope: RuntimeClosingScope.self,
                    isolatedTo: RuntimeTestActor.self,
                    onClose: { @RuntimeTestActor _ in await disposals.append("scope") },
                    provider: { @RuntimeTestActor _ in
                        await gate.wait()
                        return RuntimeCloseScopeValue()
                    }
                )
            }
        }
        let scope = try application.createScope(RuntimeClosingScope.self, id: "closing")
        let _: RuntimeRootSentinel = try scope.nonisolatedGet()

        let first = Task { try await scope.actorGet(RuntimeCloseScopeValue.self) }
        await gate.waitForArrivals(1)
        let second = Task { try await scope.actorGet(RuntimeCloseScopeValue.self) }
        let close = Task { await scope.close() }
        let scopeClosed = await waitUntilScopeIsClosed(scope)
        XCTAssertTrue(scopeClosed)
        await gate.open()

        for waiter in [first, second] {
            do {
                _ = try await waiter.value
                XCTFail("Expected scoped resolution completing during close to fail")
            } catch {
                XCTAssertTrue(hasScopeClosedUnderlying(error))
            }
        }
        await close.value
        let values = await disposals.values
        XCTAssertEqual(values, ["scope"])
    }

    @MainActor
    func testDisposalUsesReverseProviderCompletionOrder() async throws {
        let gateA = RuntimeGate()
        let gateB = RuntimeGate()
        let disposals = RuntimeRecorder()
        let application = try SkeinApplication {
            module {
                actorSingle(
                    RuntimeCompletionA.self,
                    isolatedTo: RuntimeTestActor.self,
                    onClose: { @RuntimeTestActor _ in await disposals.append("A") },
                    provider: { @RuntimeTestActor _ in
                        await gateA.wait()
                        return RuntimeCompletionA()
                    }
                )
                actorSingle(
                    RuntimeCompletionB.self,
                    isolatedTo: RuntimeTestActor.self,
                    onClose: { @RuntimeTestActor _ in await disposals.append("B") },
                    provider: { @RuntimeTestActor _ in
                        await gateB.wait()
                        return RuntimeCompletionB()
                    }
                )
            }
        }

        let resolvingA = Task { try await application.actorGet(RuntimeCompletionA.self) }
        let resolvingB = Task { try await application.actorGet(RuntimeCompletionB.self) }
        await gateA.waitForArrivals(1)
        await gateB.waitForArrivals(1)
        await gateB.open()
        _ = try await resolvingB.value
        await gateA.open()
        _ = try await resolvingA.value

        await application.close()
        let values = await disposals.values
        XCTAssertEqual(values, ["A", "B"])
    }

    @MainActor
    func testEagerFactoryRunsAtStartupAndAgainForEveryLookup() async throws {
        var creations = 0
        let application = try await SkeinApplication(validation: .declaredRoots) {
            module {
                factory(Int.self, provider: { _ in
                    creations += 1
                    return creations
                }).root(.eager)
            }
        }

        XCTAssertEqual(creations, 1)
        let first: Int = try application.get()
        let second: Int = try application.get()
        XCTAssertEqual([first, second], [2, 3])
    }

    @MainActor
    func testStructuralFailurePreventsAllEagerSideEffects() async throws {
        var eagerCreations = 0
        do {
            _ = try await SkeinApplication(validation: .declaredRoots) {
                module {
                    factory(Int.self, provider: { _ in
                        eagerCreations += 1
                        return eagerCreations
                    }).root(.eager)
                    factory(RuntimeNeedsMissing.self, using: RuntimeNeedsMissing.init).root()
                }
            }
            XCTFail("Expected structural validation to fail")
        } catch let error as GraphValidationError {
            guard case .missingBinding = error else {
                return XCTFail("Expected missingBinding, got \(error)")
            }
        }
        XCTAssertEqual(eagerCreations, 0)
    }

    @MainActor
    func testEagerRootsRunInDeclarationOrderAcrossIsolationKinds() async throws {
        let order = RuntimeLockedLog()
        _ = try await SkeinApplication(validation: .declaredRoots) {
            module {
                factory(RuntimeEagerMain.self, provider: { _ in
                    order.append("main")
                    return RuntimeEagerMain()
                }).root(.eager)
                actorFactory(
                    RuntimeEagerActor.self,
                    isolatedTo: RuntimeTestActor.self,
                    provider: { @RuntimeTestActor _ in
                        order.append("actor")
                        return RuntimeEagerActor()
                    }
                ).root(.eager)
                nonisolatedFactory(RuntimeEagerNonisolated.self, provider: { _ in
                    order.append("nonisolated")
                    return RuntimeEagerNonisolated()
                }).root(.eager)
            }
        }
        XCTAssertEqual(order.values, ["main", "actor", "nonisolated"])
    }

    @MainActor
    func testConcurrentValidatedStartIfNeededBuildsOnceAndHasOneOwner() async throws {
        stopSkein()
        defer { stopSkein() }
        let builders = RuntimeLockedCount()
        let providers = RuntimeLockedCount()
        let gate = RuntimeGate()

        let results = try await withThrowingTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await startSkeinIfNeeded(validation: .declaredRoots) {
                        countedStartupModule(builders: builders, providers: providers, gate: gate)
                    }
                }
            }
            await gate.waitForArrivals(1)
            await gate.open()
            var values: [Bool] = []
            for try await value in group { values.append(value) }
            return values
        }

        XCTAssertEqual(builders.value, 1)
        XCTAssertEqual(providers.value, 1)
        XCTAssertEqual(results.filter { $0 }.count, 1)
        XCTAssertTrue(isSkeinStarted)
    }

    @MainActor
    func testStopDuringValidatedStartupPreventsPublication() async throws {
        stopSkein()
        defer { stopSkein() }
        let gate = RuntimeGate()
        let startup = Task { @MainActor in
            try await startSkeinIfNeeded(validation: .declaredRoots) {
                module {
                    actorSingle(
                        RuntimeStartupValue.self,
                        isolatedTo: RuntimeTestActor.self,
                        provider: { @RuntimeTestActor _ in
                            await gate.wait()
                            return RuntimeStartupValue()
                        }
                    ).root(.eager)
                }
            }
        }

        await gate.waitForArrivals(1)
        stopSkein()
        XCTAssertFalse(isSkeinStarted)
        XCTAssertNil(currentSkeinValidationReport)
        await gate.open()
        do {
            _ = try await startup.value
            XCTFail("Expected stopped startup to be cancelled")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(isSkeinStarted)
        XCTAssertNil(currentSkeinValidationReport)
    }

    @MainActor
    func testCustomDisposerIsolationMismatchIsRejected() throws {
        XCTAssertThrowsError(
            try SkeinApplication {
                module {
                    actorSingle(
                        RuntimeEagerActor.self,
                        isolatedTo: RuntimeTestActor.self,
                        onClose: { @RuntimeOtherActor _ in },
                        provider: { @RuntimeTestActor _ in RuntimeEagerActor() }
                    )
                }
            }
        ) { error in
            guard case .actorIsolationMismatch = error as? SkeinError else {
                return XCTFail("Expected actorIsolationMismatch, got \(error)")
            }
        }
    }
}

private func hasUnderlying(_ error: any Error, matching expected: SkeinError) -> Bool {
    guard let resolution = error as? SkeinResolutionError,
          let underlying = resolution.underlying as? SkeinError else { return false }
    return underlying == expected
}

private func recordSkeinError(
    _ error: any Error,
    in recorder: RuntimeSkeinErrorRecorder
) async {
    guard let resolution = error as? SkeinResolutionError,
          let underlying = resolution.underlying as? SkeinError else { return }
    await recorder.append(underlying)
}

private func hasScopeClosedUnderlying(_ error: any Error) -> Bool {
    guard let resolution = error as? SkeinResolutionError,
          let underlying = resolution.underlying as? SkeinError else { return false }
    if case .scopeClosed = underlying { return true }
    return false
}

private func waitUntilApplicationIsClosed(_ application: SkeinApplication) async -> Bool {
    for _ in 0..<1_000 {
        do {
            let _: RuntimeRootSentinel = try application.nonisolatedGet()
            await Task.yield()
        } catch {
            return hasUnderlying(error, matching: .applicationClosed)
        }
    }
    return false
}

private func waitUntilScopeIsClosed(
    _ scope: SkeinScopeInstance<RuntimeClosingScope>
) async -> Bool {
    for _ in 0..<1_000 {
        do {
            let _: RuntimeRootSentinel = try scope.nonisolatedGet()
            await Task.yield()
        } catch {
            return hasScopeClosedUnderlying(error)
        }
    }
    return false
}

@MainActor
private func countedStartupModule(
    builders: RuntimeLockedCount,
    providers: RuntimeLockedCount,
    gate: RuntimeGate
) -> Module {
    builders.increment()
    return module {
        actorSingle(
            RuntimeStartupValue.self,
            isolatedTo: RuntimeTestActor.self,
            provider: { @RuntimeTestActor _ in
                providers.increment()
                await gate.wait()
                return RuntimeStartupValue()
            }
        ).root(.eager)
    }
}
