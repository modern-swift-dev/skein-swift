private func customActorIdentity<Isolation: GlobalActor>(
    _ isolation: Isolation.Type
) -> (id: ObjectIdentifier, name: String) {
    (ObjectIdentifier(Isolation.shared), String(reflecting: Isolation.self))
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
private func customActorDisposer<Service: Sendable, Isolation: GlobalActor>(
    isolatedTo: Isolation.Type,
    callback: (@isolated(any) @Sendable (Service) async -> Void)?
) -> BindingDisposer? {
    callback.map { callback in
        let identity = customActorIdentity(isolatedTo)
        return .customActor(.init(
            expectedActorID: identity.id,
            actualActorID: callback.isolation.map(ObjectIdentifier.init),
            actorName: identity.name,
            invoke: { value in
                guard let service = value.value as? Service else { return }
                await callback(service)
            }
        ))
    }
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorSingle<Service: Sendable, Isolation: GlobalActor>(
    _ type: Service.Type,
    isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@isolated(any) @Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @isolated(any) @Sendable (any Resolver) async throws -> Service
) -> Binding {
    let identity = customActorIdentity(isolatedTo)
    return Binding(
        key: BindingKey(type, qualifier: qualifier), lifetime: .single,
        isolation: .customActor(id: identity.id, name: identity.name),
        provider: .customActor(.init(
            expectedActorID: identity.id,
            actualActorID: provider.isolation.map(ObjectIdentifier.init),
            actorName: identity.name,
            invoke: { .init(value: try await provider($0)) }
        )),
        disposer: customActorDisposer(isolatedTo: isolatedTo, callback: onClose),
        source: .init(fileID: fileID, line: line)
    )
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorFactory<Service: Sendable, Isolation: GlobalActor>(
    _ type: Service.Type,
    isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @isolated(any) @Sendable (any Resolver) async throws -> Service
) -> Binding {
    let identity = customActorIdentity(isolatedTo)
    return Binding(
        key: BindingKey(type, qualifier: qualifier), lifetime: .factory,
        isolation: .customActor(id: identity.id, name: identity.name),
        provider: .customActor(.init(
            expectedActorID: identity.id,
            actualActorID: provider.isolation.map(ObjectIdentifier.init),
            actorName: identity.name,
            invoke: { .init(value: try await provider($0)) }
        )), source: .init(fileID: fileID, line: line)
    )
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorFactory<Service: Sendable, Arguments: Sendable, Isolation: GlobalActor>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @isolated(any) @Sendable (any Resolver, Arguments) async throws -> Service
) -> Binding {
    let identity = customActorIdentity(isolatedTo)
    return Binding(
        key: BindingKey(type, qualifier: qualifier, argumentType: arguments), lifetime: .factory,
        isolation: .customActor(id: identity.id, name: identity.name),
        provider: .customActorAssisted(.init(
            expectedActorID: identity.id,
            actualActorID: provider.isolation.map(ObjectIdentifier.init),
            actorName: identity.name,
            invoke: { resolver, value in
                guard let arguments = value.value as? Arguments else {
                    throw SkeinError.resolvedTypeMismatch(
                        expected: String(reflecting: Arguments.self),
                        actual: String(reflecting: Swift.type(of: value.value))
                    )
                }
                return .init(value: try await provider(resolver, arguments))
            }
        )), source: .init(fileID: fileID, line: line)
    )
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorScoped<Service: Sendable, Scope: SkeinScope, Isolation: GlobalActor>(
    _ type: Service.Type,
    scope: Scope.Type,
    isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@isolated(any) @Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @isolated(any) @Sendable (any Resolver) async throws -> Service
) -> Binding {
    let identity = customActorIdentity(isolatedTo)
    return Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
        isolation: .customActor(id: identity.id, name: identity.name),
        provider: .customActor(.init(
            expectedActorID: identity.id,
            actualActorID: provider.isolation.map(ObjectIdentifier.init),
            actorName: identity.name,
            invoke: { .init(value: try await provider($0)) }
        )), disposer: customActorDisposer(isolatedTo: isolatedTo, callback: onClose),
        source: .init(fileID: fileID, line: line)
    )
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorScoped<Service: Sendable, Scope: SkeinScope, Isolation: GlobalActor>(
    _ scope: Scope.Type,
    _ type: Service.Type,
    isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@isolated(any) @Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @isolated(any) @Sendable (any Resolver) async throws -> Service
) -> Binding {
    actorScoped(type, scope: scope, isolatedTo: isolatedTo, qualifier: qualifier,
                onClose: onClose, fileID: fileID, line: line, provider: provider)
}

public func actorInstance<Value: Sendable, Isolation: GlobalActor>(
    _ value: Value,
    isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    actorInstance(Value.self, value: value, isolatedTo: isolatedTo,
                  qualifier: qualifier, fileID: fileID, line: line)
}

public func actorInstance<Service: Sendable, Isolation: GlobalActor>(
    _ type: Service.Type,
    value: Service,
    isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    let identity = customActorIdentity(isolatedTo)
    return Binding(
        key: BindingKey(type, qualifier: qualifier), lifetime: .single,
        isolation: .customActor(id: identity.id, name: identity.name),
        provider: .customActor(.init(expectedActorID: identity.id, actualActorID: identity.id,
                                     actorName: identity.name,
                                     invoke: { _ in .init(value: value) })),
        source: .init(fileID: fileID, line: line), dependencies: []
    )
}
