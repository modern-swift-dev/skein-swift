import Foundation

package final class Container: Resolver, @unchecked Sendable {
    private enum State { case active, closing, closed }

    package struct CachedInstance: @unchecked Sendable {
        package let value: Any
        package let disposer: BindingDisposer?
    }

    private struct InFlight: @unchecked Sendable {
        let identity: AsyncCreationIdentity
        let task: Task<UncheckedProviderValue, Error>
        let disposer: BindingDisposer?
    }

    private enum AsyncSingletonState: @unchecked Sendable {
        case inFlight(InFlight)
        case resolved(CachedInstance)
    }

    private let lock = NSRecursiveLock()
    private let bindings: [BindingKey: [Binding]]
    private let declaredRoots: [Binding]
    private var singletons: [BindingKey: CachedInstance] = [:]
    private var asyncSingletons: [BindingKey: AsyncSingletonState] = [:]
    private var completedInstances: [CachedInstance] = []
    private var asyncWaitEdges: [AsyncCreationIdentity: Set<AsyncCreationIdentity>] = [:]
    private var scopes: [ScopeIdentity: any ScopeStorage] = [:]
    private var scopeCreationOrder: [ScopeIdentity] = []
    private var state: State = .active
    private var closeWaiters: [() -> Void] = []

    package init(modules: [Module]) throws {
        var collected: [BindingKey: [Binding]] = [:]
        var roots: [Binding] = []
        for module in modules {
            for binding in module.bindings {
                var matching = collected[binding.key, default: []]
                if let original = matching.first(where: { existing in
                    switch (existing.lifetime, binding.lifetime) {
                        case (.single, .single), (.single, .factory),
                             (.factory, .single), (.factory, .factory): true
                        case let (.scoped(lhs, _), .scoped(rhs, _)): lhs == rhs
                        default: false
                    }
                }) {
                    throw SkeinConfigurationError(
                        underlying: .duplicateBinding(
                            type: binding.key.typeName,
                            qualifier: binding.key.qualifier?.description
                        ),
                        firstRegistration: original.source,
                        duplicateRegistration: binding.source
                    )
                }
                try Self.validateDynamicIsolation(of: binding)
                if binding.rootPolicy != nil, !binding.lifetime.isRoot {
                    throw SkeinError.scopedBindingCannotBeRoot(
                        type: binding.key.typeName,
                        qualifier: binding.key.qualifier?.description
                    )
                }
                if binding.rootPolicy == .eager, binding.key.argumentTypeName != nil {
                    throw SkeinError.eagerAssistedRoot(
                        type: binding.key.typeName,
                        qualifier: binding.key.qualifier?.description
                    )
                }
                matching.append(binding)
                collected[binding.key] = matching
                if binding.rootPolicy != nil { roots.append(binding) }
            }
        }
        bindings = collected
        declaredRoots = roots
    }

    @MainActor package func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try resolveMainActor(type, qualifier: qualifier, arguments: Never?.none)
    }

    @MainActor package func assistedGet<Service, Arguments>(
        _ type: Service.Type,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try resolveMainActor(type, qualifier: qualifier, arguments: Optional(arguments))
    }

    package func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try resolveNonisolated(type, qualifier: qualifier, arguments: Never?.none)
    }

    package func nonisolatedAssistedGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try resolveNonisolated(type, qualifier: qualifier, arguments: Optional(arguments))
    }

    package func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service {
        try await resolveActor(type, qualifier: qualifier, arguments: Never?.none)
    }

    package func actorAssistedGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service {
        try await resolveActor(type, qualifier: qualifier, arguments: Optional(arguments))
    }

    @MainActor package func resolveMainActor<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?,
        arguments: Any?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        do {
            let binding = try rootBinding(for: key)
            let value: Any
            switch binding.provider {
                case let .mainActor(provider):
                    value = try resolveSynchronousRoot(key: key, binding: binding) { try provider(self) }
                case let .nonisolated(provider):
                    value = try resolveSynchronousRoot(key: key, binding: binding) { try provider(self) }
                case let .mainActorAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    value = try resolveSynchronousRoot(key: key, binding: binding) { try provider(self, arguments) }
                case let .nonisolatedAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    value = try resolveSynchronousRoot(key: key, binding: binding) { try provider(self, arguments) }
                case .customActor, .customActorAssisted:
                    throw isolationError(key, required: "MainActor or nonisolated", actual: binding.isolation)
            }
            return try cast(value, to: type)
        } catch {
            throw resolutionError(error, appending: key, source: rootSource(for: key))
        }
    }

    package func resolveNonisolated<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?,
        arguments: Any?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        do {
            let binding = try rootBinding(for: key)
            let value: Any
            switch binding.provider {
                case let .nonisolated(provider):
                    value = try resolveSynchronousRoot(key: key, binding: binding) { try provider(self) }
                case let .nonisolatedAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    value = try resolveSynchronousRoot(key: key, binding: binding) { try provider(self, arguments) }
                case .mainActor, .mainActorAssisted, .customActor, .customActorAssisted:
                    throw isolationError(key, required: "nonisolated", actual: binding.isolation)
            }
            return try cast(value, to: type)
        } catch {
            throw resolutionError(error, appending: key, source: rootSource(for: key))
        }
    }

    package func resolveActor<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?,
        arguments: Any?
    ) async throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        do {
            let binding = try rootBinding(for: key)
            let value = try await resolveAnyActor(key: key, binding: binding, arguments: arguments)
            return try cast(value, to: type)
        } catch {
            throw resolutionError(error, appending: key, source: rootSource(for: key))
        }
    }

    @MainActor package func resolveMainActorInScope<Kind: SkeinScope, Service>(
        _ scope: SkeinScopeInstance<Kind>, type: Service.Type,
        qualifier: (any SkeinQualifier)?, arguments: Any?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        do {
            let binding = try scopedBinding(for: key, scopeType: ObjectIdentifier(Kind.self))
            if binding.lifetime.isRoot { return try resolveMainActor(type, qualifier: qualifier, arguments: arguments) }
            let value: Any
            switch binding.provider {
                case let .mainActor(provider): value = try scope.resolve(key: key, binding: binding) { try provider(scope) }
                case let .nonisolated(provider): value = try scope.resolve(key: key, binding: binding) { try provider(scope) }
                case let .mainActorAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    value = try scope.resolve(key: key, binding: binding) { try provider(scope, arguments) }
                case let .nonisolatedAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    value = try scope.resolve(key: key, binding: binding) { try provider(scope, arguments) }
                case .customActor, .customActorAssisted:
                    throw isolationError(key, required: "MainActor or nonisolated", actual: binding.isolation)
            }
            return try cast(value, to: type)
        } catch {
            throw resolutionError(error, appending: key, source: preferredBinding(for: key, scopeType: ObjectIdentifier(Kind.self))?.source)
        }
    }

    package func resolveNonisolatedInScope<Kind: SkeinScope, Service: Sendable>(
        _ scope: SkeinScopeInstance<Kind>, type: Service.Type,
        qualifier: (any SkeinQualifier)?, arguments: Any?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        do {
            let binding = try scopedBinding(for: key, scopeType: ObjectIdentifier(Kind.self))
            if binding.lifetime.isRoot { return try resolveNonisolated(type, qualifier: qualifier, arguments: arguments) }
            let value: Any
            switch binding.provider {
                case let .nonisolated(provider): value = try scope.resolve(key: key, binding: binding) { try provider(scope) }
                case let .nonisolatedAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    value = try scope.resolve(key: key, binding: binding) { try provider(scope, arguments) }
                case .mainActor, .mainActorAssisted, .customActor, .customActorAssisted:
                    throw isolationError(key, required: "nonisolated", actual: binding.isolation)
            }
            return try cast(value, to: type)
        } catch {
            throw resolutionError(error, appending: key, source: preferredBinding(for: key, scopeType: ObjectIdentifier(Kind.self))?.source)
        }
    }

    package func resolveActorInScope<Kind: SkeinScope, Service: Sendable>(
        _ scope: SkeinScopeInstance<Kind>, type: Service.Type,
        qualifier: (any SkeinQualifier)?, arguments: Any?
    ) async throws -> Service {
        let key = BindingKey(type, qualifier: qualifier, argumentType: arguments.map { Swift.type(of: $0) })
        do {
            let binding = try scopedBinding(for: key, scopeType: ObjectIdentifier(Kind.self))
            if binding.lifetime.isRoot { return try await resolveActor(type, qualifier: qualifier, arguments: arguments) }
            let value: Any
            let resolver: any Resolver = scope
            switch binding.provider {
                case let .mainActor(provider):
                    let boxedBinding = UncheckedBinding(value: binding)
                    value = try await MainActor.run {
                        try UncheckedProviderValue(value: scope.resolve(key: key, binding: boxedBinding.value) {
                            try provider(resolver)
                        })
                    }.value
                case let .mainActorAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    let boxedArguments = UncheckedProviderValue(value: arguments)
                    let boxedBinding = UncheckedBinding(value: binding)
                    value = try await MainActor.run {
                        try UncheckedProviderValue(value: scope.resolve(key: key, binding: boxedBinding.value) {
                            try provider(resolver, boxedArguments.value)
                        })
                    }.value
                case let .nonisolated(provider):
                    value = try scope.resolve(key: key, binding: binding) { try provider(resolver) }
                case let .nonisolatedAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    value = try scope.resolve(key: key, binding: binding) { try provider(resolver, arguments) }
                case let .customActor(provider):
                    value = try await scope.resolveAsync(key: key, binding: binding) {
                        try await provider.invoke(resolver).value
                    }
                case let .customActorAssisted(provider):
                    guard let arguments else { throw missing(key) }
                    let boxed = UncheckedProviderValue(value: arguments)
                    value = try await scope.resolveAsync(key: key, binding: binding) {
                        try await provider.invoke(resolver, boxed).value
                    }
            }
            return try cast(value, to: type)
        } catch {
            throw resolutionError(error, appending: key, source: preferredBinding(for: key, scopeType: ObjectIdentifier(Kind.self))?.source)
        }
    }

    private func resolveAnyActor(
        key: BindingKey, binding: Binding, arguments: Any?
    ) async throws -> Any {
        let resolver: any Resolver = self
        switch binding.provider {
            case let .mainActor(provider):
                let boxedBinding = UncheckedBinding(value: binding)
                return try await MainActor.run {
                    try UncheckedProviderValue(value: resolveSynchronousRoot(key: key, binding: boxedBinding.value) {
                        try provider(resolver)
                    })
                }.value
            case let .mainActorAssisted(provider):
                guard let arguments else { throw missing(key) }
                let boxed = UncheckedProviderValue(value: arguments)
                let boxedBinding = UncheckedBinding(value: binding)
                return try await MainActor.run {
                    try UncheckedProviderValue(value: resolveSynchronousRoot(key: key, binding: boxedBinding.value) {
                        try provider(resolver, boxed.value)
                    })
                }.value
            case let .nonisolated(provider):
                return try resolveSynchronousRoot(key: key, binding: binding) { try provider(resolver) }
            case let .nonisolatedAssisted(provider):
                guard let arguments else { throw missing(key) }
                return try resolveSynchronousRoot(key: key, binding: binding) { try provider(resolver, arguments) }
            case let .customActor(provider):
                return try await resolveAsyncRoot(key: key, binding: binding) { try await provider.invoke(resolver).value }
            case let .customActorAssisted(provider):
                guard let arguments else { throw missing(key) }
                let boxed = UncheckedProviderValue(value: arguments)
                return try await resolveAsyncRoot(key: key, binding: binding) {
                    try await provider.invoke(resolver, boxed).value
                }
        }
    }

    private func resolveSynchronousRoot(
        key: BindingKey, binding: Binding, provider: () throws -> Any
    ) throws -> Any {
        lock.lock()
        defer { lock.unlock() }
        try ensureActive()
        if case .single = binding.lifetime, let cached = singletons[key] { return cached.value }
        let value = try withResolution(of: key, context: ObjectIdentifier(self), source: binding.source, provider)
        if case .single = binding.lifetime {
            let cached = CachedInstance(value: value, disposer: binding.disposer)
            singletons[key] = cached
            completedInstances.append(cached)
        }
        return value
    }

    private func resolveAsyncRoot(
        key: BindingKey, binding: Binding,
        provider: @escaping @Sendable () async throws -> Any
    ) async throws -> Any {
        guard case .single = binding.lifetime else {
            try lock.withLock { try ensureActive() }
            let value = try await withAsyncResolution(
                of: key, context: ObjectIdentifier(self), source: binding.source, provider
            )
            try lock.withLock { try ensureActive() }
            return value
        }
        return try await withAsyncResolution(of: key, context: ObjectIdentifier(self), source: binding.source) {
            let captured = ResolutionContext.entries
            let selected: AsyncSingletonState = try lock.withLock {
                try ensureActive()
                if let existing = asyncSingletons[key] { return existing }
                let token = UUID()
                let identity = AsyncCreationIdentity(
                    context: ObjectIdentifier(self), token: token, key: key
                )
                let task = Task.detached { [self] in
                    try await AsyncCreationContext.$current.withValue(identity) {
                        try await ResolutionContext.$entries.withValue(captured) {
                            let value = UncheckedProviderValue(value: try await provider())
                            recordAsyncSingletonCompletion(key: key, token: token, value: value)
                            return value
                        }
                    }
                }
                let inFlight = InFlight(identity: identity, task: task, disposer: binding.disposer)
                asyncSingletons[key] = .inFlight(inFlight)
                return .inFlight(inFlight)
            }
            switch selected {
                case let .resolved(cached): return cached.value
                case let .inFlight(inFlight):
                    let waitEdge = try beginAsyncWait(on: inFlight.identity)
                    defer { endAsyncWait(waitEdge) }
                    do {
                        let value = try await inFlight.task.value
                        return try finishAsyncSingleton(key: key, inFlight: inFlight, value: value).value
                    } catch {
                        lock.withLock {
                            if case let .inFlight(current) = asyncSingletons[key],
                               current.identity.token == inFlight.identity.token {
                                asyncSingletons.removeValue(forKey: key)
                            }
                        }
                        throw error
                    }
            }
        }
    }

    private func finishAsyncSingleton(
        key: BindingKey, inFlight: InFlight, value: UncheckedProviderValue
    ) throws -> CachedInstance {
        try lock.withLock {
            try ensureActive()
            if case let .resolved(cached) = asyncSingletons[key] { return cached }
            // The provider task records success before publishing its result.
            // Reaching this branch means closure state was invalidated.
            throw SkeinError.applicationClosed
        }
    }

    private func recordAsyncSingletonCompletion(
        key: BindingKey, token: UUID, value: UncheckedProviderValue
    ) {
        lock.withLock {
            guard case let .inFlight(current) = asyncSingletons[key],
                  current.identity.token == token else { return }
            let cached = CachedInstance(value: value.value, disposer: current.disposer)
            asyncSingletons[key] = .resolved(cached)
            completedInstances.append(cached)
        }
    }

    package func createScope<Kind: SkeinScope>(
        _ type: Kind.Type, id: some Hashable & Sendable
    ) throws -> SkeinScopeInstance<Kind> {
        try lock.withLock {
            try ensureActive()
            let identity = ScopeIdentity(type: type, id: id)
            guard scopes[identity] == nil else {
                throw SkeinError.duplicateScope(scope: identity.typeName, id: identity.idDescription)
            }
            let scope = SkeinScopeInstance<Kind>(container: self, identity: identity)
            scopes[identity] = scope
            scopeCreationOrder.append(identity)
            return scope
        }
    }

    package func detachScope(_ identity: ScopeIdentity) {
        lock.withLock {
            scopes.removeValue(forKey: identity)
            scopeCreationOrder.removeAll { $0 == identity }
        }
    }

    package func validateGraph() throws -> GraphValidationReport {
        var opaque: [OpaqueBinding] = []
        var opaqueNodes: Set<ValidationNodeIdentity> = []
        for root in declaredRoots {
            guard root.lifetime.isRoot else {
                throw SkeinError.scopedBindingCannotBeRoot(
                    type: root.key.typeName, qualifier: root.key.qualifier?.description
                )
            }
            if root.rootPolicy == .eager, root.key.argumentTypeName != nil {
                throw SkeinError.eagerAssistedRoot(
                    type: root.key.typeName, qualifier: root.key.qualifier?.description
                )
            }
            try validate(root.key, binding: root, parent: nil, path: [], active: [], opaque: &opaque, opaqueNodes: &opaqueNodes)
        }
        return GraphValidationReport(opaqueBindings: opaque)
    }

    package func validateDeclaredRootsAndStart() async throws -> GraphValidationReport {
        let report = try validateGraph()
        for binding in declaredRoots where binding.rootPolicy == .eager {
            try Task.checkCancellation()
            _ = try await resolveAnyActor(key: binding.key, binding: binding, arguments: nil)
        }
        return report
    }

    package func close() async {
        let owner = ObjectIdentifier(self)
        if DisposalContext.owners.contains(owner) { return }
        let work: (scopes: [any ScopeStorage], inFlight: [InFlight])? = lock.withLock {
            guard case .active = state else { return nil }
            state = .closing
            let activeScopes = scopeCreationOrder.reversed().compactMap { scopes[$0] }
            let tasks = asyncSingletons.values.compactMap { state -> InFlight? in
                guard case let .inFlight(value) = state else { return nil }
                return value
            }
            return (activeScopes, tasks)
        }
        guard let work else { await waitUntilClosed(); return }

        await DisposalContext.$owners.withValue(DisposalContext.owners.union([owner])) {
            for scope in work.scopes { await scope.close() }
            await withTaskGroup(of: Void.self) { group in
                for inFlight in work.inFlight {
                    group.addTask {
                        _ = try? await inFlight.task.value
                    }
                }
            }
            let completed = lock.withLock { completedInstances.reversed() }
            for instance in completed { await dispose(instance.value, using: instance.disposer) }
        }

        let waiters = lock.withLock {
            singletons.removeAll(); asyncSingletons.removeAll(); completedInstances.removeAll()
            asyncWaitEdges.removeAll()
            scopes.removeAll(); scopeCreationOrder.removeAll(); state = .closed
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

    package func withResolution<Result>(
        of key: BindingKey, context: ObjectIdentifier,
        source: SkeinSourceLocation? = nil, _ resolve: () throws -> Result
    ) throws -> Result {
        let entries = ResolutionContext.entries
        if let start = entries.firstIndex(where: { $0.context == context && $0.key == key }) {
            throw SkeinError.circularDependency(path: (Array(entries[start...]).map(\.key) + [key]).map(\.description))
        }
        let entry = ResolutionTraceEntry(key: key, context: context, source: source)
        return try ResolutionContext.$entries.withValue(entries + [entry], operation: resolve)
    }

    package func withAsyncResolution<Result>(
        of key: BindingKey, context: ObjectIdentifier,
        source: SkeinSourceLocation? = nil,
        _ resolve: () async throws -> Result
    ) async throws -> Result {
        let entries = ResolutionContext.entries
        if let start = entries.firstIndex(where: { $0.context == context && $0.key == key }) {
            throw SkeinError.circularDependency(path: (Array(entries[start...]).map(\.key) + [key]).map(\.description))
        }
        let entry = ResolutionTraceEntry(key: key, context: context, source: source)
        return try await ResolutionContext.$entries.withValue(entries + [entry], operation: resolve)
    }

    package func beginAsyncWait(on target: AsyncCreationIdentity) throws -> AsyncWaitEdge? {
        guard let source = AsyncCreationContext.current else { return nil }
        return try lock.withLock {
            var visited: Set<AsyncCreationIdentity> = []
            if let path = asyncWaitPath(from: target, to: source, visited: &visited) {
                throw SkeinError.circularDependency(
                    path: ([source] + path).map { $0.key.description }
                )
            }
            asyncWaitEdges[source, default: []].insert(target)
            return AsyncWaitEdge(source: source, target: target)
        }
    }

    package func endAsyncWait(_ edge: AsyncWaitEdge?) {
        guard let edge else { return }
        lock.withLock {
            asyncWaitEdges[edge.source]?.remove(edge.target)
            if asyncWaitEdges[edge.source]?.isEmpty == true {
                asyncWaitEdges.removeValue(forKey: edge.source)
            }
        }
    }

    private func asyncWaitPath(
        from current: AsyncCreationIdentity,
        to goal: AsyncCreationIdentity,
        visited: inout Set<AsyncCreationIdentity>
    ) -> [AsyncCreationIdentity]? {
        if current == goal { return [current] }
        guard visited.insert(current).inserted else { return nil }
        for next in asyncWaitEdges[current] ?? [] {
            if let suffix = asyncWaitPath(from: next, to: goal, visited: &visited) {
                return [current] + suffix
            }
        }
        return nil
    }

    package func cast<Service>(_ value: Any, to type: Service.Type) throws -> Service {
        guard let resolved = value as? Service else {
            throw SkeinError.resolvedTypeMismatch(
                expected: String(reflecting: type), actual: String(reflecting: Swift.type(of: value))
            )
        }
        return resolved
    }

    private func rootBinding(for key: BindingKey) throws -> Binding {
        guard let binding = bindings[key]?.first(where: \.lifetime.isRoot) else { throw missing(key) }
        return binding
    }

    private func scopedBinding(for key: BindingKey, scopeType: ObjectIdentifier) throws -> Binding {
        guard let binding = preferredBinding(for: key, scopeType: scopeType) else { throw missing(key) }
        return binding
    }

    private func preferredBinding(for key: BindingKey, scopeType: ObjectIdentifier) -> Binding? {
        let candidates = bindings[key] ?? []
        return candidates.first {
            if case let .scoped(type, _) = $0.lifetime { return type == scopeType }
            return false
        } ?? candidates.first(where: \.lifetime.isRoot)
    }

    private func rootSource(for key: BindingKey) -> SkeinSourceLocation? {
        bindings[key]?.first(where: \.lifetime.isRoot)?.source
    }

    private func resolutionError(
        _ error: any Error, appending key: BindingKey, source: SkeinSourceLocation?
    ) -> SkeinResolutionError {
        if let existing = error as? SkeinResolutionError { return existing }
        let frames = ResolutionContext.entries.map {
            SkeinResolutionFrame(type: $0.key.typeName, qualifier: $0.key.qualifier?.description,
                                 argumentType: $0.key.argumentTypeName, registration: $0.source)
        }
        let leaf = SkeinResolutionFrame(type: key.typeName, qualifier: key.qualifier?.description,
                                        argumentType: key.argumentTypeName, registration: source)
        return SkeinResolutionError(underlying: error, path: frames + [leaf])
    }

    private func validate(
        _ key: BindingKey, binding: Binding? = nil, parent: Binding?, path: [String],
        active: Set<ValidationNodeIdentity>, opaque: inout [OpaqueBinding],
        opaqueNodes: inout Set<ValidationNodeIdentity>
    ) throws {
        let candidates = bindings[key] ?? []
        guard let binding = binding ?? validationBinding(from: candidates, parent: parent) else {
            throw GraphValidationError.missingBinding(
                type: key.typeName, qualifier: key.qualifier?.description, path: path + [key.description]
            )
        }
        let nextPath = path + [key.description]
        let identity = ValidationNodeIdentity(key: key, lifetime: binding.lifetime)
        if active.contains(identity) { throw GraphValidationError.circularDependency(path: nextPath) }
        if let parent {
            if parent.lifetime.isRoot, case let .scoped(_, scope) = binding.lifetime {
                throw GraphValidationError.rootDependsOnScopedBinding(path: nextPath, scope: scope)
            }
            if case let .scoped(fromType, fromName) = parent.lifetime,
               case let .scoped(toType, toName) = binding.lifetime, fromType != toType {
                throw GraphValidationError.crossScopeDependency(path: nextPath, from: fromName, to: toName)
            }
            if !Self.canDepend(parent.isolation, on: binding.isolation) {
                throw GraphValidationError.isolationMismatch(
                    path: nextPath,
                    parent: parent.isolation.description,
                    dependency: binding.isolation.description
                )
            }
        }
        guard let dependencies = binding.dependencies else {
            if opaqueNodes.insert(identity).inserted {
                opaque.append(.init(type: key.typeName, qualifier: key.qualifier?.description,
                                    registration: binding.source, isolation: binding.isolation.description))
            }
            return
        }
        var nextActive = active; nextActive.insert(identity)
        for dependency in dependencies {
            try validate(dependency.key, parent: binding, path: nextPath, active: nextActive,
                         opaque: &opaque, opaqueNodes: &opaqueNodes)
        }
    }

    private func validationBinding(from candidates: [Binding], parent: Binding?) -> Binding? {
        guard let parent else { return candidates.first(where: \.lifetime.isRoot) ?? candidates.first }
        switch parent.lifetime {
            case .single, .factory:
                return candidates.first(where: \.lifetime.isRoot) ?? candidates.first
            case let .scoped(scopeType, _):
                return candidates.first {
                    if case let .scoped(type, _) = $0.lifetime { type == scopeType } else { false }
                } ?? candidates.first(where: \.lifetime.isRoot) ?? candidates.first
        }
    }

    private func ensureActive() throws {
        guard case .active = state else { throw SkeinError.applicationClosed }
    }

    private func missing(_ key: BindingKey) -> SkeinError {
        .missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
    }

    private func isolationError(
        _ key: BindingKey, required: String, actual: BindingIsolation
    ) -> SkeinError {
        .bindingIsolationMismatch(type: key.typeName, qualifier: key.qualifier?.description,
                                  required: required, actual: actual.diagnosticName)
    }

    private static func canDepend(_ parent: BindingIsolation, on dependency: BindingIsolation) -> Bool {
        switch parent {
            case .mainActor: dependency == .mainActor || dependency == .nonisolated
            case .nonisolated: dependency == .nonisolated
            case .customActor: true
        }
    }

    private static func validateDynamicIsolation(of binding: Binding) throws {
        let providers: [(ObjectIdentifier, ObjectIdentifier?, String)]
        switch binding.provider {
            case let .customActor(storage):
                providers = [(storage.expectedActorID, storage.actualActorID, storage.actorName)]
            case let .customActorAssisted(storage):
                providers = [(storage.expectedActorID, storage.actualActorID, storage.actorName)]
            default: providers = []
        }
        var checks = providers
        if case let .customActor(storage)? = binding.disposer {
            checks.append((storage.expectedActorID, storage.actualActorID, storage.actorName))
        }
        if let expected = checks.first(where: { $0.0 != $0.1 }) {
            throw SkeinError.actorIsolationMismatch(
                type: binding.key.typeName, qualifier: binding.key.qualifier?.description,
                expected: expected.2, actual: expected.1.map { String(describing: $0) }
            )
        }
    }
}

private struct ValidationNodeIdentity: Hashable {
    let key: BindingKey
    let scopeType: ObjectIdentifier?
    init(key: BindingKey, lifetime: BindingLifetime) {
        self.key = key
        if case let .scoped(type, _) = lifetime { scopeType = type } else { scopeType = nil }
    }
}

private struct UncheckedBinding: @unchecked Sendable {
    let value: Binding
}

private extension BindingIsolation {
    var diagnosticName: String {
        switch self {
            case .mainActor: "MainActor"
            case .nonisolated: "nonisolated"
            case let .customActor(_, name): name
        }
    }
}

package func dispose(_ value: Any, using disposer: BindingDisposer?) async {
    let boxed = UncheckedProviderValue(value: value)
    switch disposer {
        case let .mainActor(callback): await callback(boxed)
        case let .nonisolated(callback): await callback(boxed)
        case let .customActor(storage): await storage.invoke(boxed)
        case nil: break
    }
}

package enum DisposalContext {
    @TaskLocal package static var owners: Set<ObjectIdentifier> = []
}
