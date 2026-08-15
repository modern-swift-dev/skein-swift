import Foundation

/// A flat, typed scope that inherits bindings from its application.
///
/// A scope may be shared across concurrency domains. Call ``close()`` to dispose completed
/// instances; resolution attempts after closing fail with a scope-lifecycle error.
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

    /// The identity under which the container tracks this scope.
    package let identity: ScopeIdentity
    private let lock = NSRecursiveLock()
    private var state: State = .active
    private var closeWaiters: [() -> Void] = []
    private var instances: [BindingKey: Container.CachedInstance] = [:]
    private var asyncInstances: [BindingKey: AsyncState] = [:]
    private var completedInstances: [Container.CachedInstance] = []

    /// Creates an empty scope managed by a container.
    ///
    /// - Parameters:
    ///   - container: The container that owns the scope.
    ///   - identity: The identity of the scope.
    package init(container: Container, identity: ScopeIdentity) {
        self.container = container
        self.identity = identity
    }

    /// Creates a scope with an existing service instance in its cache.
    ///
    /// - Parameters:
    ///   - container: The container that owns the scope.
    ///   - identity: The identity of the scope.
    ///   - seededKey: The binding key associated with the seeded service.
    ///   - seededValue: The service instance placed in the scope cache.
    ///   - seededDisposer: The disposer to invoke for the seeded service when the scope closes.
    package init(
        container: Container,
        identity: ScopeIdentity,
        seededKey: BindingKey,
        seededValue: some Sendable,
        seededDisposer: BindingDisposer?
    ) {
        self.container = container
        self.identity = identity
        let cached = Container.CachedInstance(value: seededValue, disposer: seededDisposer)
        instances[seededKey] = cached
        asyncInstances[seededKey] = .resolved(cached)
        completedInstances.append(cached)
    }

    /// Resolves a service in this scope on the main actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error, a scope-lifecycle error, or an error from the provider.
    @MainActor public func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.resolveMainActorInScope(
            self, type: type, qualifier: qualifier, arguments: Never?.none
        )
    }

    /// Resolves an assisted service in this scope on the main actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The arguments passed to the assisted provider.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error, a scope-lifecycle error, or an error from the provider.
    @MainActor public func get<Service>(
        _ type: Service.Type = Service.self,
        arguments: some Any,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.resolveMainActorInScope(
            self, type: type, qualifier: qualifier, arguments: Optional(arguments)
        )
    }

    /// Resolves a sendable service in this scope without actor isolation.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error, a scope-lifecycle error, or an error from the provider.
    public func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.resolveNonisolatedInScope(
            self, type: type, qualifier: qualifier, arguments: Never?.none
        )
    }

    /// Resolves an assisted sendable service in this scope without actor isolation.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The sendable arguments passed to the assisted provider.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error, a scope-lifecycle error, or an error from the provider.
    public func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: some Sendable,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.resolveNonisolatedInScope(
            self, type: type, qualifier: qualifier, arguments: Optional(arguments)
        )
    }

    /// Resolves a sendable service in this scope using its required actor isolation.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error, a scope-lifecycle error, or an error from the provider.
    public func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service {
        try await container.resolveActorInScope(
            self, type: type, qualifier: qualifier, arguments: Never?.none
        )
    }

    /// Resolves an assisted sendable service in this scope using its required actor isolation.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The sendable arguments passed to the assisted provider.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error, a scope-lifecycle error, or an error from the provider.
    public func actorGet<Service: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: some Sendable,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await container.resolveActorInScope(
            self, type: type, qualifier: qualifier, arguments: Optional(arguments)
        )
    }

    /// Resolves and caches a synchronous scoped binding.
    ///
    /// - Parameters:
    ///   - key: The key of the binding being resolved.
    ///   - binding: The scoped binding that supplies the service.
    ///   - provider: The operation that creates the service when it is not cached.
    /// - Returns: The cached or newly created service value.
    /// - Throws: A circular-dependency or scope-lifecycle error, or an error from `provider`.
    package func resolve(
        key: BindingKey, binding: Binding, provider: () throws -> Any
    ) throws -> Any {
        lock.lock()
        defer { lock.unlock() }
        try ensureActiveLocked()
        if let cached = instances[key] {
            return cached.value
        }
        let value = try container.withResolution(
            of: key, context: ObjectIdentifier(self), source: binding.source, provider
        )
        let cached = Container.CachedInstance(value: value, disposer: binding.disposer)
        instances[key] = cached
        completedInstances.append(cached)
        return value
    }

    /// Resolves and caches an asynchronous scoped binding.
    ///
    /// Concurrent requests for the same binding share one in-flight creation.
    ///
    /// - Parameters:
    ///   - key: The key of the binding being resolved.
    ///   - binding: The scoped binding that supplies the service.
    ///   - provider: The asynchronous operation that creates the service when it is not cached.
    /// - Returns: The cached or newly created service value.
    /// - Throws: A circular-dependency or scope-lifecycle error, or an error from `provider`.
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
                if let existing = self.asyncInstances[key] {
                    return existing
                }
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
            if case let .resolved(cached) = asyncInstances[key] {
                return cached
            }
            throw SkeinError.scopeClosed(scope: identity.typeName, id: identity.idDescription)
        }
    }

    private func recordCompletion(key: BindingKey, token: UUID, value: UncheckedProviderValue) {
        lock.withLock {
            guard case let .inFlight(current) = asyncInstances[key],
                  current.identity.token == token else {
                return
            }
            let cached = Container.CachedInstance(value: value.value, disposer: current.disposer)
            asyncInstances[key] = .resolved(cached)
            completedInstances.append(cached)
        }
    }

    /// Closes the scope and disposes completed instances in reverse creation order.
    ///
    /// Closing is idempotent. Concurrent callers wait for the first close operation to finish,
    /// and subsequent resolution attempts fail because the scope is closed.
    public func close() async {
        let owner = ObjectIdentifier(self)
        if DisposalContext.owners.contains(owner) {
            return
        }
        let inFlight: [InFlight]? = lock.withLock {
            guard case .active = state else {
                return nil
            }
            state = .closing
            return asyncInstances.values.compactMap { state in
                guard case let .inFlight(value) = state else {
                    return nil
                }
                return value
            }
        }
        guard let inFlight else {
            await waitUntilClosed(); return
        }

        await DisposalContext.$owners.withValue(DisposalContext.owners.union([owner])) {
            for pending in inFlight {
                _ = try? await pending.task.value
            }
            let completed = lock.withLock { completedInstances.reversed() }
            for instance in completed {
                await dispose(instance.value, using: instance.disposer)
            }
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
                if case .closed = state {
                    continuation.resume()
                } else {
                    closeWaiters.append { continuation.resume() }
                }
            }
        }
    }

    private func ensureActiveLocked() throws {
        guard case .active = state else {
            throw SkeinError.scopeClosed(scope: identity.typeName, id: identity.idDescription)
        }
    }
}
