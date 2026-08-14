import Foundation

/// A marker protocol used to define a typed scope kind.
public protocol KoinScope {}

package struct ScopeIdentity: Hashable, @unchecked Sendable {
    package let type: ObjectIdentifier
    package let typeName: String
    package let id: AnyHashable
    package let idDescription: String

    package init(type: (some KoinScope).Type, id: some Hashable & Sendable) {
        self.type = ObjectIdentifier(type)
        typeName = String(reflecting: type)
        self.id = AnyHashable(id)
        idDescription = String(describing: id)
    }
}

package protocol ScopeStorage: AnyObject, Sendable {
    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) func close() async
}

/// A flat, typed scope that inherits bindings from its application.
public final class KoinScopeInstance<Kind: KoinScope>: Resolver, ScopeStorage, @unchecked Sendable {
    private enum State { case active, closing, closed }
    private struct CachedInstance {
        let value: Any
        let disposer: BindingDisposer?
    }

    private let container: Container
    package let identity: ScopeIdentity
    private let lock = NSRecursiveLock()
    private var state: State = .active
    private var closeWaiters: [() -> Void] = []
    private var instances: [BindingKey: CachedInstance] = [:]
    private var creationOrder: [BindingKey] = []

    package init(container: Container, identity: ScopeIdentity) {
        self.container = container
        self.identity = identity
    }

    public func get<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?
    ) throws -> Service {
        try container.resolveInScope(
            self,
            type: type,
            qualifier: qualifier,
            arguments: Never?.none
        )
    }

    public func get<Service>(
        _ type: Service.Type = Service.self,
        arguments: some Any,
        qualifier: (any KoinQualifier)? = nil
    ) throws -> Service {
        try container.resolveInScope(
            self,
            type: type,
            qualifier: qualifier,
            arguments: Optional(arguments)
        )
    }

    @MainActor public func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?
    ) throws -> Service {
        try container.mainActorResolveInScope(
            self,
            type: type,
            qualifier: qualifier,
            arguments: Never?.none
        )
    }

    @MainActor public func mainActorGet<Service>(
        _ type: Service.Type = Service.self,
        arguments: some Any,
        qualifier: (any KoinQualifier)? = nil
    ) throws -> Service {
        try container.mainActorResolveInScope(
            self,
            type: type,
            qualifier: qualifier,
            arguments: Optional(arguments)
        )
    }

    package func resolve<Service>(
        _ type: Service.Type,
        key: BindingKey,
        binding: Binding,
        provider: () throws -> Any
    ) throws -> Service {
        lock.lock()
        defer { lock.unlock() }
        try ensureActive()
        if let instance = instances[key] {
            return try container.cast(instance.value, to: type)
        }
        let value = try container.withResolution(
            of: key,
            context: ObjectIdentifier(self),
            source: binding.source,
            provider
        )
        let resolved: Service = try container.cast(value, to: type)
        instances[key] = CachedInstance(value: resolved, disposer: binding.disposer)
        creationOrder.append(key)
        return resolved
    }

    package func ensureActive() throws {
        lock.lock()
        defer { lock.unlock() }
        guard case .active = state else {
            throw KoinError.scopeClosed(scope: identity.typeName, id: identity.idDescription)
        }
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) public func close() async {
        let owner = ObjectIdentifier(self)
        if DisposalContext.owners.contains(owner) {
            return
        }
        let work: [CachedInstance]? = lock.withLock {
            switch state {
                case .closed,
                     .closing: return nil
                case .active:
                    state = .closing
                    return creationOrder.reversed().compactMap { instances[$0] }
            }
        }
        guard let work else {
            await waitUntilClosed()
            return
        }
        await DisposalContext.$owners.withValue(DisposalContext.owners.union([owner])) {
            for instance in work {
                await dispose(instance.value, using: instance.disposer)
            }
        }
        container.detachScope(identity)
        let waiters: [() -> Void] = lock.withLock {
            instances.removeAll()
            creationOrder.removeAll()
            state = .closed
            let waiters = closeWaiters
            closeWaiters.removeAll()
            return waiters
        }
        waiters.forEach { $0() }
    }

    @available(macOS 10.15, *) private func waitUntilClosed() async {
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
}
