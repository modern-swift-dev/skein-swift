import Foundation

/// A marker protocol used to define a typed scope kind.
public protocol SkeinScope {}

package struct ScopeIdentity: Hashable, @unchecked Sendable {
    package let type: ObjectIdentifier
    package let typeName: String
    package let id: AnyHashable
    package let idDescription: String

    package init(type: (some SkeinScope).Type, id: some Hashable & Sendable) {
        self.type = ObjectIdentifier(type)
        typeName = String(reflecting: type)
        self.id = AnyHashable(id)
        idDescription = String(describing: id)
    }
}

package protocol ScopeStorage: AnyObject, Sendable {
    func close() async
}

/// A flat, typed scope that inherits bindings from its application.
public final class SkeinScopeInstance<Kind: SkeinScope>: Resolver, ScopeStorage, @unchecked Sendable {
    private enum State { case active, closing, closed }
    private struct InFlight: @unchecked Sendable {
        let identity: AsyncCreationIdentity
        let task: Task<UncheckedProviderValue, Error>
        let disposer: BindingDisposer?
    }
    private enum AsyncState: @unchecked Sendable {
        case inFlight(InFlight)
        case resolved(Container.CachedInstance)
    }

    private let container: Container
    package let identity: ScopeIdentity
    private let lock = NSRecursiveLock()
    private var state: State = .active
    private var closeWaiters: [() -> Void] = []
    private var instances: [BindingKey: Container.CachedInstance] = [:]
    private var asyncInstances: [BindingKey: AsyncState] = [:]
    private var completedInstances: [Container.CachedInstance] = []

    package init(container: Container, identity: ScopeIdentity) {
        self.container = container
        self.identity = identity
    }

    @MainActor public func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.resolveMainActorInScope(
            self, type: type, qualifier: qualifier, arguments: Never?.none
        )
    }

    @MainActor public func get<Service, Arguments>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.resolveMainActorInScope(
            self, type: type, qualifier: qualifier, arguments: Optional(arguments)
        )
    }

    public func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.resolveNonisolatedInScope(
            self, type: type, qualifier: qualifier, arguments: Never?.none
        )
    }

    public func nonisolatedGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.resolveNonisolatedInScope(
            self, type: type, qualifier: qualifier, arguments: Optional(arguments)
        )
    }

    public func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service {
        try await container.resolveActorInScope(
            self, type: type, qualifier: qualifier, arguments: Never?.none
        )
    }

    public func actorGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await container.resolveActorInScope(
            self, type: type, qualifier: qualifier, arguments: Optional(arguments)
        )
    }

    package func resolve(
        key: BindingKey, binding: Binding, provider: () throws -> Any
    ) throws -> Any {
        lock.lock()
        defer { lock.unlock() }
        try ensureActiveLocked()
        if let cached = instances[key] { return cached.value }
        let value = try container.withResolution(
            of: key, context: ObjectIdentifier(self), source: binding.source, provider
        )
        let cached = Container.CachedInstance(value: value, disposer: binding.disposer)
        instances[key] = cached
        completedInstances.append(cached)
        return value
    }

    package func resolveAsync(
        key: BindingKey, binding: Binding,
        provider: @escaping @Sendable () async throws -> Any
    ) async throws -> Any {
        try await container.withAsyncResolution(
            of: key, context: ObjectIdentifier(self), source: binding.source
        ) {
            let captured = ResolutionContext.entries
            let selected: AsyncState = try self.lock.withLock {
                try self.ensureActiveLocked()
                if let existing = self.asyncInstances[key] { return existing }
                let token = UUID()
                let identity = AsyncCreationIdentity(
                    context: ObjectIdentifier(self), token: token, key: key
                )
                let task = Task.detached { [self] in
                    try await AsyncCreationContext.$current.withValue(identity) {
                        try await ResolutionContext.$entries.withValue(captured) {
                            let value = UncheckedProviderValue(value: try await provider())
                            recordCompletion(key: key, token: token, value: value)
                            return value
                        }
                    }
                }
                let inFlight = InFlight(identity: identity, task: task, disposer: binding.disposer)
                self.asyncInstances[key] = .inFlight(inFlight)
                return .inFlight(inFlight)
            }
            switch selected {
                case let .resolved(cached): return cached.value
                case let .inFlight(inFlight):
                    let waitEdge = try self.container.beginAsyncWait(on: inFlight.identity)
                    defer { self.container.endAsyncWait(waitEdge) }
                    do {
                        let value = try await inFlight.task.value
                        return try self.finish(key: key, inFlight: inFlight, value: value).value
                    } catch {
                        self.lock.withLock {
                            if case let .inFlight(current) = self.asyncInstances[key],
                               current.identity.token == inFlight.identity.token {
                                self.asyncInstances.removeValue(forKey: key)
                            }
                        }
                        throw error
                    }
            }
        }
    }

    private func finish(
        key: BindingKey, inFlight: InFlight, value: UncheckedProviderValue
    ) throws -> Container.CachedInstance {
        try lock.withLock {
            try ensureActiveLocked()
            if case let .resolved(cached) = asyncInstances[key] { return cached }
            throw SkeinError.scopeClosed(scope: identity.typeName, id: identity.idDescription)
        }
    }

    private func recordCompletion(key: BindingKey, token: UUID, value: UncheckedProviderValue) {
        lock.withLock {
            guard case let .inFlight(current) = asyncInstances[key],
                  current.identity.token == token else { return }
            let cached = Container.CachedInstance(value: value.value, disposer: current.disposer)
            asyncInstances[key] = .resolved(cached)
            completedInstances.append(cached)
        }
    }

    public func close() async {
        let owner = ObjectIdentifier(self)
        if DisposalContext.owners.contains(owner) { return }
        let inFlight: [InFlight]? = lock.withLock {
            guard case .active = state else { return nil }
            state = .closing
            return asyncInstances.values.compactMap { state in
                guard case let .inFlight(value) = state else { return nil }
                return value
            }
        }
        guard let inFlight else { await waitUntilClosed(); return }

        await DisposalContext.$owners.withValue(DisposalContext.owners.union([owner])) {
            for pending in inFlight {
                _ = try? await pending.task.value
            }
            let completed = lock.withLock { completedInstances.reversed() }
            for instance in completed { await dispose(instance.value, using: instance.disposer) }
        }
        container.detachScope(identity)
        let waiters = lock.withLock {
            instances.removeAll(); asyncInstances.removeAll(); completedInstances.removeAll()
            state = .closed
            defer { closeWaiters.removeAll() }
            return closeWaiters
        }
        waiters.forEach { $0() }
    }

    private func waitUntilClosed() async {
        await withCheckedContinuation(isolation: nil) { continuation in
            lock.withLock {
                if case .closed = state { continuation.resume() }
                else { closeWaiters.append { continuation.resume() } }
            }
        }
    }

    private func ensureActiveLocked() throws {
        guard case .active = state else {
            throw SkeinError.scopeClosed(scope: identity.typeName, id: identity.idDescription)
        }
    }
}
