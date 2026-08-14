import Foundation

package final class Container: Resolver, @unchecked Sendable {
    private static let resolutionStacksKey = "Koin.ResolutionStacks"

    private enum State {
        case active
        case closing
        case closed
    }

    private struct CachedInstance {
        let value: Any
        let disposer: BindingDisposer?
    }

    private let lock = NSRecursiveLock()
    private let bindings: [BindingKey: [Binding]]
    private let validationRoots: [ValidationRoot]
    private var singletons: [BindingKey: CachedInstance] = [:]
    private var singletonCreationOrder: [BindingKey] = []
    private var scopes: [ScopeIdentity: any ScopeStorage] = [:]
    private var scopeCreationOrder: [ScopeIdentity] = []
    private var state: State = .active
    private var closeWaiters: [() -> Void] = []

    package init(modules: [Module]) throws {
        var collected: [BindingKey: [Binding]] = [:]
        for module in modules {
            for binding in module.bindings {
                var matching = collected[binding.key, default: []]
                if let original = matching.first(where: { existing in
                    switch (existing.lifetime, binding.lifetime) {
                        case (.single, .single),
                             (.single, .factory),
                             (.factory, .single),
                             (.factory, .factory):
                            true
                        case let (.scoped(lhs, _), .scoped(rhs, _)):
                            lhs == rhs
                        default:
                            false
                    }
                }) {
                    throw KoinConfigurationError(
                        underlying: .duplicateBinding(
                            type: binding.key.typeName,
                            qualifier: binding.key.qualifier?.description
                        ),
                        firstRegistration: original.source,
                        duplicateRegistration: binding.source
                    )
                }
                matching.append(binding)
                collected[binding.key] = matching
            }
        }
        bindings = collected
        validationRoots = modules.flatMap(\.validationRoots)
    }

    package func get<Service>(_ type: Service.Type, qualifier: (any KoinQualifier)?) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier)
        do {
            return try resolve(type, qualifier: qualifier, arguments: Never?.none)
        } catch {
            throw resolutionError(error, appending: key, source: rootSource(for: key))
        }
    }

    package func assistedGet<Service, Arguments>(
        _ type: Service.Type,
        arguments: Arguments,
        qualifier: (any KoinQualifier)?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: Arguments.self)
        do {
            return try resolve(type, qualifier: qualifier, arguments: Optional(arguments))
        } catch {
            throw resolutionError(error, appending: key, source: rootSource(for: key))
        }
    }

    @MainActor package func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier)
        do {
            return try mainActorResolve(type, qualifier: qualifier, arguments: Never?.none)
        } catch {
            throw resolutionError(error, appending: key, source: rootSource(for: key))
        }
    }

    @MainActor package func mainActorAssistedGet<Service, Arguments>(
        _ type: Service.Type,
        arguments: Arguments,
        qualifier: (any KoinQualifier)?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: Arguments.self)
        do {
            return try mainActorResolve(type, qualifier: qualifier, arguments: Optional(arguments))
        } catch {
            throw resolutionError(error, appending: key, source: rootSource(for: key))
        }
    }

    package func resolve<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?,
        arguments: (some Any)?
    ) throws -> Service {
        lock.lock()
        defer { lock.unlock() }
        try ensureActive()

        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        let binding = try rootBinding(for: key)
        switch binding.provider {
            case let .standard(provider):
                return try resolveRoot(type, key: key, binding: binding) { try provider(self) }
            case let .standardAssisted(provider):
                guard let arguments else {
                    throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
                }
                return try resolveRoot(type, key: key, binding: binding) { try provider(self, arguments) }
            case .mainActor,
                 .mainActorAssisted:
                throw KoinError.mainActorBindingRequiresMainActor(
                    type: key.typeName,
                    qualifier: key.qualifier?.description
                )
        }
    }

    @MainActor package func mainActorResolve<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?,
        arguments: (some Any)?
    ) throws -> Service {
        lock.lock()
        defer { lock.unlock() }
        try ensureActive()

        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        let binding = try rootBinding(for: key)
        switch binding.provider {
            case let .standard(provider):
                return try resolveRoot(type, key: key, binding: binding) { try provider(self) }
            case let .mainActor(provider):
                return try resolveRoot(type, key: key, binding: binding) { try provider(self) }
            case let .standardAssisted(provider):
                guard let arguments else {
                    throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
                }
                return try resolveRoot(type, key: key, binding: binding) { try provider(self, arguments) }
            case let .mainActorAssisted(provider):
                guard let arguments else {
                    throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
                }
                return try resolveRoot(type, key: key, binding: binding) { try provider(self, arguments) }
        }
    }

    package func resolveInScope<Kind: KoinScope, Service>(
        _ scope: KoinScopeInstance<Kind>,
        type: Service.Type,
        qualifier: (any KoinQualifier)?,
        arguments: (some Any)?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        lock.lock()
        defer { lock.unlock() }
        do {
            try ensureActive()
            try scope.ensureActive()
            guard let binding = preferredBinding(for: key, scopeType: ObjectIdentifier(Kind.self)) else {
                throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
            }
            if binding.lifetime.isRoot {
                return try resolve(type, qualifier: qualifier, arguments: arguments)
            }
            switch binding.provider {
                case let .standard(provider):
                    return try scope.resolve(type, key: key, binding: binding) { try provider(scope) }
                case .mainActor:
                    throw KoinError.mainActorBindingRequiresMainActor(
                        type: key.typeName,
                        qualifier: key.qualifier?.description
                    )
                case let .standardAssisted(provider):
                    guard let arguments else {
                        throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
                    }
                    return try scope.resolve(type, key: key, binding: binding) { try provider(scope, arguments) }
                case .mainActorAssisted:
                    throw KoinError.mainActorBindingRequiresMainActor(
                        type: key.typeName,
                        qualifier: key.qualifier?.description
                    )
            }
        } catch {
            let source = preferredBinding(for: key, scopeType: ObjectIdentifier(Kind.self))?.source
            throw resolutionError(error, appending: key, source: source)
        }
    }

    @MainActor package func mainActorResolveInScope<Kind: KoinScope, Service>(
        _ scope: KoinScopeInstance<Kind>,
        type: Service.Type,
        qualifier: (any KoinQualifier)?,
        arguments: (some Any)?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        lock.lock()
        defer { lock.unlock() }
        do {
            try ensureActive()
            try scope.ensureActive()
            guard let binding = preferredBinding(for: key, scopeType: ObjectIdentifier(Kind.self)) else {
                throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
            }
            if binding.lifetime.isRoot {
                return try mainActorResolve(type, qualifier: qualifier, arguments: arguments)
            }
            switch binding.provider {
                case let .standard(provider):
                    return try scope.resolve(type, key: key, binding: binding) { try provider(scope) }
                case let .mainActor(provider):
                    return try scope.resolve(type, key: key, binding: binding) { try provider(scope) }
                case let .standardAssisted(provider):
                    guard let arguments else {
                        throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
                    }
                    return try scope.resolve(type, key: key, binding: binding) { try provider(scope, arguments) }
                case let .mainActorAssisted(provider):
                    guard let arguments else {
                        throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
                    }
                    return try scope.resolve(type, key: key, binding: binding) { try provider(scope, arguments) }
            }
        } catch {
            let source = preferredBinding(for: key, scopeType: ObjectIdentifier(Kind.self))?.source
            throw resolutionError(error, appending: key, source: source)
        }
    }

    package func createScope<Kind: KoinScope>(
        _ type: Kind.Type,
        id: some Hashable & Sendable
    ) throws -> KoinScopeInstance<Kind> {
        lock.lock()
        defer { lock.unlock() }
        try ensureActive()
        let identity = ScopeIdentity(type: type, id: id)
        guard scopes[identity] == nil else {
            throw KoinError.duplicateScope(scope: identity.typeName, id: identity.idDescription)
        }
        let scope = KoinScopeInstance<Kind>(container: self, identity: identity)
        scopes[identity] = scope
        scopeCreationOrder.append(identity)
        return scope
    }

    package func detachScope(_ identity: ScopeIdentity) {
        lock.lock()
        scopes.removeValue(forKey: identity)
        scopeCreationOrder.removeAll { $0 == identity }
        lock.unlock()
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) package func close() async {
        let owner = ObjectIdentifier(self)
        if DisposalContext.owners.contains(owner) {
            return
        }
        let work: (scopes: [any ScopeStorage], instances: [CachedInstance])? = lock.withLock {
            switch state {
                case .closed:
                    return nil
                case .closing:
                    return nil
                case .active:
                    state = .closing
                    let activeScopes = scopeCreationOrder.reversed().compactMap { scopes[$0] }
                    let instances = singletonCreationOrder.reversed().compactMap { singletons[$0] }
                    return (activeScopes, instances)
            }
        }
        guard let work else {
            await waitUntilClosed()
            return
        }

        await DisposalContext.$owners.withValue(DisposalContext.owners.union([owner])) {
            for scope in work.scopes {
                await scope.close()
            }
            for instance in work.instances {
                await dispose(instance.value, using: instance.disposer)
            }
        }

        let waiters: [() -> Void] = lock.withLock {
            singletons.removeAll()
            singletonCreationOrder.removeAll()
            scopes.removeAll()
            scopeCreationOrder.removeAll()
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

    private func rootBinding(for key: BindingKey) throws -> Binding {
        guard let binding = bindings[key]?.first(where: \.lifetime.isRoot) else {
            throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
        }
        return binding
    }

    private func preferredBinding(for key: BindingKey, scopeType: ObjectIdentifier) -> Binding? {
        let candidates = bindings[key] ?? []
        return candidates.first { binding in
            if case let .scoped(type, _) = binding.lifetime {
                return type == scopeType
            }
            return false
        } ?? candidates.first(where: \.lifetime.isRoot)
    }

    private func resolveRoot<Service>(
        _ type: Service.Type,
        key: BindingKey,
        binding: Binding,
        provider: () throws -> Any
    ) throws -> Service {
        if case .single = binding.lifetime, let instance = singletons[key] {
            return try cast(instance.value, to: type)
        }
        let instance = try withResolution(
            of: key,
            context: ObjectIdentifier(self),
            source: binding.source,
            provider
        )
        let resolved: Service = try cast(instance, to: type)
        if case .single = binding.lifetime {
            singletons[key] = CachedInstance(value: resolved, disposer: binding.disposer)
            singletonCreationOrder.append(key)
        }
        return resolved
    }

    package func withResolution<Result>(
        of key: BindingKey,
        context: ObjectIdentifier,
        source: KoinSourceLocation? = nil,
        _ resolve: () throws -> Result
    ) throws -> Result {
        let stacks = resolutionStacks()
        var keys = stacks.keysByContext[context, default: []]
        if let cycleStart = keys.firstIndex(of: key) {
            let path = Array(keys[cycleStart...]) + [key]
            throw KoinError.circularDependency(path: path.map(\.description))
        }
        keys.append(key)
        stacks.keysByContext[context] = keys
        stacks.trace.append(ResolutionTraceEntry(key: key, source: source))
        defer {
            stacks.keysByContext[context]?.removeLast()
            if stacks.keysByContext[context]?.isEmpty == true {
                stacks.keysByContext.removeValue(forKey: context)
            }
            stacks.trace.removeLast()
        }
        return try resolve()
    }

    package func validateGraph() throws -> GraphValidationReport {
        var opaque: [OpaqueBinding] = []
        var opaqueNodes: Set<ValidationNodeIdentity> = []
        for root in validationRoots {
            let candidates = bindings[root.key] ?? []
            guard !candidates.isEmpty else {
                throw GraphValidationError.missingBinding(
                    type: root.key.typeName,
                    qualifier: root.key.qualifier?.description,
                    path: [root.key.description]
                )
            }
            for binding in candidates {
                try validate(
                    root.key,
                    binding: binding,
                    parent: nil,
                    path: [],
                    active: [],
                    opaque: &opaque,
                    opaqueNodes: &opaqueNodes
                )
            }
        }
        return GraphValidationReport(opaqueBindings: opaque)
    }

    package func cast<Service>(_ value: Any, to type: Service.Type) throws -> Service {
        guard let resolved = value as? Service else {
            throw KoinError.resolvedTypeMismatch(
                expected: String(reflecting: type),
                actual: String(reflecting: Swift.type(of: value))
            )
        }
        return resolved
    }

    private func rootSource(for key: BindingKey) -> KoinSourceLocation? {
        bindings[key]?.first(where: \.lifetime.isRoot)?.source
    }

    private func resolutionError(
        _ error: any Error,
        appending key: BindingKey,
        source: KoinSourceLocation?
    ) -> KoinResolutionError {
        if let existing = error as? KoinResolutionError {
            return existing
        }
        let leaf = KoinResolutionFrame(
            type: key.typeName,
            qualifier: key.qualifier?.description,
            argumentType: key.argumentTypeName,
            registration: source
        )
        let frames = resolutionStacks().trace.map { entry in
            KoinResolutionFrame(
                type: entry.key.typeName,
                qualifier: entry.key.qualifier?.description,
                argumentType: entry.key.argumentTypeName,
                registration: entry.source
            )
        }
        return KoinResolutionError(underlying: error, path: frames + [leaf])
    }

    private func validate(
        _ key: BindingKey,
        binding: Binding? = nil,
        parent: Binding?,
        path: [String],
        active: Set<ValidationNodeIdentity>,
        opaque: inout [OpaqueBinding],
        opaqueNodes: inout Set<ValidationNodeIdentity>
    ) throws {
        let candidates = bindings[key] ?? []
        guard let binding = binding ?? validationBinding(from: candidates, parent: parent) else {
            throw GraphValidationError.missingBinding(
                type: key.typeName,
                qualifier: key.qualifier?.description,
                path: path + [key.description]
            )
        }
        let nextPath = path + [key.description]
        let identity = ValidationNodeIdentity(key: key, lifetime: binding.lifetime)

        if active.contains(identity) {
            throw GraphValidationError.circularDependency(path: nextPath)
        }
        if let parent {
            if parent.lifetime.isRoot, case let .scoped(_, scope) = binding.lifetime {
                throw GraphValidationError.rootDependsOnScopedBinding(path: nextPath, scope: scope)
            }
            if case let .scoped(fromType, fromName) = parent.lifetime,
               case let .scoped(toType, toName) = binding.lifetime,
               fromType != toType {
                throw GraphValidationError.crossScopeDependency(
                    path: nextPath,
                    from: fromName,
                    to: toName
                )
            }
            if !parent.provider.isMainActor, binding.provider.isMainActor {
                throw GraphValidationError.mainActorDependencyRequiresMainActor(path: nextPath)
            }
        }

        guard let dependencies = binding.dependencies else {
            if opaqueNodes.insert(identity).inserted {
                opaque.append(OpaqueBinding(
                    type: key.typeName,
                    qualifier: key.qualifier?.description,
                    registration: binding.source
                ))
            }
            return
        }
        var nextActive = active
        nextActive.insert(identity)
        for dependency in dependencies {
            try validate(
                dependency.key,
                parent: binding,
                path: nextPath,
                active: nextActive,
                opaque: &opaque,
                opaqueNodes: &opaqueNodes
            )
        }
    }

    private func validationBinding(from candidates: [Binding], parent: Binding?) -> Binding? {
        guard let parent else {
            return candidates.first(where: \.lifetime.isRoot) ?? candidates.first
        }
        switch parent.lifetime {
            case .single,
                 .factory:
                return candidates.first(where: \.lifetime.isRoot) ?? candidates.first
            case let .scoped(scopeType, _):
                return candidates.first {
                    if case let .scoped(type, _) = $0.lifetime {
                        return type == scopeType
                    }
                    return false
                } ?? candidates.first(where: \.lifetime.isRoot) ?? candidates.first
        }
    }

    private func ensureActive() throws {
        guard case .active = state else {
            throw KoinError.applicationClosed
        }
    }

    private func resolutionStacks() -> ResolutionStacks {
        let dictionary = Thread.current.threadDictionary
        if let stacks = dictionary[Self.resolutionStacksKey] as? ResolutionStacks {
            return stacks
        }
        let stacks = ResolutionStacks()
        dictionary[Self.resolutionStacksKey] = stacks
        return stacks
    }
}

private extension BindingProvider {
    var isMainActor: Bool {
        switch self {
            case .mainActor,
                 .mainActorAssisted: true
            case .standard,
                 .standardAssisted: false
        }
    }
}

private struct ValidationNodeIdentity: Hashable {
    let key: BindingKey
    let scopeType: ObjectIdentifier?

    init(key: BindingKey, lifetime: BindingLifetime) {
        self.key = key
        if case let .scoped(type, _) = lifetime {
            scopeType = type
        } else {
            scopeType = nil
        }
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) package func dispose(_ value: Any, using disposer: BindingDisposer?) async {
    switch disposer {
        case let .standard(callback): await callback(value)
        case let .mainActor(callback): await callback(UncheckedDisposalValue(value: value))
        case nil: break
    }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) package enum DisposalContext {
    @TaskLocal package static var owners: Set<ObjectIdentifier> = []
}
