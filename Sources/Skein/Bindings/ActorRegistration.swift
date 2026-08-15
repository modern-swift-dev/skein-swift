private func customActorIdentity<Isolation: GlobalActor>(
    _ isolation: Isolation.Type
) -> (id: ObjectIdentifier, name: String) {
    (ObjectIdentifier(Isolation.shared), String(reflecting: Isolation.self))
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) private func customActorDisposer<Service: Sendable>(
    isolatedTo: (some GlobalActor).Type,
    callback: (@isolated(any) @Sendable (Service) async -> Void)?
) -> BindingDisposer? {
    callback.map { callback in
        let identity = customActorIdentity(isolatedTo)
        return .customActor(.init(
            expectedActorID: identity.id,
            actualActorID: callback.isolation.map(ObjectIdentifier.init),
            actorName: identity.name,
            invoke: { value in
                guard let service = value.value as? Service else {
                    return
                }
                await callback(service)
            }
        ))
    }
}

/// Registers a lazily created singleton isolated to a custom global actor.
///
/// - Parameters:
///   - type: The service type to register.
///   - isolatedTo: The global actor on which the provider and disposer execute.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional actor-isolated callback run when the cached service is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The actor-isolated asynchronous closure that creates the service.
/// - Returns: A singleton binding for the service.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorSingle<Service: Sendable>(
    _ type: Service.Type,
    isolatedTo: (some GlobalActor).Type,
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

/// Registers a custom-actor factory that creates a value for each resolution.
///
/// - Parameters:
///   - type: The service type to register.
///   - isolatedTo: The global actor on which the provider executes.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The actor-isolated asynchronous closure that creates the service.
/// - Returns: A factory binding for the service.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorFactory<Service: Sendable>(
    _ type: Service.Type,
    isolatedTo: (some GlobalActor).Type,
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

/// Registers an assisted factory isolated to a custom global actor.
///
/// - Parameters:
///   - type: The service type to register.
///   - arguments: The assisted argument type required for resolution.
///   - isolatedTo: The global actor on which the provider executes.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The actor-isolated asynchronous closure that creates the service.
/// - Returns: An assisted factory binding for the service.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorFactory<Service: Sendable, Arguments: Sendable>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    isolatedTo: (some GlobalActor).Type,
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

/// Registers a custom-actor service cached once per scope instance.
///
/// - Parameters:
///   - type: The service type to register.
///   - scope: The scope kind that owns cached values.
///   - isolatedTo: The global actor on which the provider and disposer execute.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional actor-isolated callback run when the scoped value is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The actor-isolated asynchronous closure that creates the service.
/// - Returns: A scoped binding for the service.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorScoped<Service: Sendable>(
    _ type: Service.Type,
    scope: (some SkeinScope).Type,
    isolatedTo: (some GlobalActor).Type,
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

/// Registers a custom-actor scoped service, with the scope listed first.
///
/// - Parameters:
///   - scope: The scope kind that owns cached values.
///   - type: The service type to register.
///   - isolatedTo: The global actor on which the provider and disposer execute.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional actor-isolated callback run when the scoped value is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The actor-isolated asynchronous closure that creates the service.
/// - Returns: A scoped binding for the service.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorScoped<Service: Sendable>(
    _ scope: (some SkeinScope).Type,
    _ type: Service.Type,
    isolatedTo: (some GlobalActor).Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@isolated(any) @Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @isolated(any) @Sendable (any Resolver) async throws -> Service
) -> Binding {
    actorScoped(
        type,
        scope: scope,
        isolatedTo: isolatedTo,
        qualifier: qualifier,
        onClose: onClose,
        fileID: fileID,
        line: line,
        provider: provider
    )
}

/// Registers an existing sendable value under its concrete type and custom actor identity.
///
/// - Parameters:
///   - value: The value to register.
///   - isolatedTo: The global actor associated with the binding.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
/// - Returns: A singleton binding for the value.
public func actorInstance<Value: Sendable>(
    _ value: Value,
    isolatedTo: (some GlobalActor).Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    actorInstance(
        Value.self,
        value: value,
        isolatedTo: isolatedTo,
        qualifier: qualifier,
        fileID: fileID,
        line: line
    )
}

/// Registers an existing sendable value under an explicit service type and custom actor identity.
///
/// - Parameters:
///   - type: The service type to register.
///   - value: The value supplied by the binding.
///   - isolatedTo: The global actor associated with the binding.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
/// - Returns: A singleton binding for the service.
public func actorInstance<Service: Sendable>(
    _ type: Service.Type,
    value: Service,
    isolatedTo: (some GlobalActor).Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    let identity = customActorIdentity(isolatedTo)
    return Binding(
        key: BindingKey(type, qualifier: qualifier), lifetime: .single,
        isolation: .customActor(id: identity.id, name: identity.name),
        provider: .customActor(.init(
            expectedActorID: identity.id,
            actualActorID: identity.id,
            actorName: identity.name,
            invoke: { _ in .init(value: value) }
        )),
        source: .init(fileID: fileID, line: line), dependencies: []
    )
}
