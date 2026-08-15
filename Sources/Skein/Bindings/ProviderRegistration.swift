private func mainActorDisposer<Service>(
    _ callback: (@MainActor (Service) async -> Void)?
) -> BindingDisposer? {
    callback.map { callback in
        .mainActor { value in
            guard let service = value.value as? Service else {
                return
            }
            await callback(service)
        }
    }
}

private func nonisolatedDisposer<Service: Sendable>(
    _ callback: (@Sendable (Service) async -> Void)?
) -> BindingDisposer? {
    callback.map { callback in
        .nonisolated { value in
            guard let service = value.value as? Service else {
                return
            }
            await callback(service)
        }
    }
}

// MARK: MainActor providers

/// Registers a lazily created main-actor singleton.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional asynchronous callback run when the cached service is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The main-actor closure that creates the service.
/// - Returns: A singleton binding for the service.
@MainActor public func single<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        isolation: .mainActor,
        provider: .mainActor { try provider($0) },
        disposer: mainActorDisposer(onClose),
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers a main-actor factory that creates a value for each resolution.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The main-actor closure that creates the service.
/// - Returns: A factory binding for the service.
@MainActor public func factory<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .factory,
        isolation: .mainActor,
        provider: .mainActor { try provider($0) },
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers an assisted main-actor factory.
///
/// - Parameters:
///   - type: The service type to register.
///   - arguments: The assisted argument type required for resolution.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The main-actor closure that creates the service from assisted arguments.
/// - Returns: An assisted factory binding for the service.
@MainActor public func factory<Service, Arguments>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver, Arguments) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier, argumentType: arguments),
        lifetime: .factory,
        isolation: .mainActor,
        provider: .mainActorAssisted { resolver, value in
            guard let arguments = value as? Arguments else {
                throw argumentMismatch(Arguments.self, value)
            }
            return try provider(resolver, arguments)
        },
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers a main-actor service cached once per scope instance.
///
/// - Parameters:
///   - type: The service type to register.
///   - scope: The scope kind that owns cached values.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional asynchronous callback run when the scoped value is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The main-actor closure that creates the service.
/// - Returns: A scoped binding for the service.
@MainActor public func scoped<Service>(
    _ type: Service.Type,
    scope: (some SkeinScope).Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
        isolation: .mainActor,
        provider: .mainActor { try provider($0) },
        disposer: mainActorDisposer(onClose),
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers a main-actor service cached once per scope instance, with the scope listed first.
///
/// - Parameters:
///   - scope: The scope kind that owns cached values.
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional asynchronous callback run when the scoped value is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The main-actor closure that creates the service.
/// - Returns: A scoped binding for the service.
@MainActor public func scoped<Service>(
    _ scope: (some SkeinScope).Type,
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    scoped(type, scope: scope, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line, provider: provider)
}

/// Registers an existing value as a main-actor singleton under its concrete type.
///
/// - Parameters:
///   - value: The value to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
/// - Returns: A singleton binding for the value.
@MainActor public func instance<Value>(
    _ value: Value,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    instance(Value.self, value: value, qualifier: qualifier, fileID: fileID, line: line)
}

/// Registers an existing value as a main-actor singleton under an explicit service type.
///
/// - Parameters:
///   - type: The service type to register.
///   - value: The value supplied by the binding.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
/// - Returns: A singleton binding for the service.
@MainActor public func instance<Service>(
    _ type: Service.Type,
    value: Service,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        isolation: .mainActor,
        provider: .mainActor { _ in value },
        source: .init(fileID: fileID, line: line),
        dependencies: []
    )
}

// MARK: Nonisolated providers

/// Registers a lazily created sendable nonisolated singleton.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional sendable callback run when the cached service is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The sendable closure that creates the service.
/// - Returns: A singleton binding for the service.
public func nonisolatedSingle<Service: Sendable>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        isolation: .nonisolated,
        provider: .nonisolated { try provider($0) },
        disposer: nonisolatedDisposer(onClose),
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers a sendable nonisolated factory that creates a value for each resolution.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The sendable closure that creates the service.
/// - Returns: A factory binding for the service.
public func nonisolatedFactory<Service: Sendable>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .factory,
        isolation: .nonisolated,
        provider: .nonisolated { try provider($0) },
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers an assisted sendable nonisolated factory.
///
/// - Parameters:
///   - type: The service type to register.
///   - arguments: The assisted argument type required for resolution.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The sendable closure that creates the service from assisted arguments.
/// - Returns: An assisted factory binding for the service.
public func nonisolatedFactory<Service: Sendable, Arguments: Sendable>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver, Arguments) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier, argumentType: arguments),
        lifetime: .factory,
        isolation: .nonisolated,
        provider: .nonisolatedAssisted { resolver, value in
            guard let arguments = value as? Arguments else {
                throw argumentMismatch(Arguments.self, value)
            }
            return try provider(resolver, arguments)
        },
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers a sendable nonisolated service cached once per scope instance.
///
/// - Parameters:
///   - type: The service type to register.
///   - scope: The scope kind that owns cached values.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional sendable callback run when the scoped value is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The sendable closure that creates the service.
/// - Returns: A scoped binding for the service.
public func nonisolatedScoped<Service: Sendable>(
    _ type: Service.Type,
    scope: (some SkeinScope).Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
        isolation: .nonisolated,
        provider: .nonisolated { try provider($0) },
        disposer: nonisolatedDisposer(onClose),
        source: .init(fileID: fileID, line: line)
    )
}

/// Registers a sendable nonisolated scoped service, with the scope listed first.
///
/// - Parameters:
///   - scope: The scope kind that owns cached values.
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional sendable callback run when the scoped value is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - provider: The sendable closure that creates the service.
/// - Returns: A scoped binding for the service.
public func nonisolatedScoped<Service: Sendable>(
    _ scope: (some SkeinScope).Type,
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    nonisolatedScoped(type, scope: scope, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line, provider: provider)
}

/// Registers an existing sendable value as a nonisolated singleton under its concrete type.
///
/// - Parameters:
///   - value: The value to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
/// - Returns: A singleton binding for the value.
public func nonisolatedInstance<Value: Sendable>(
    _ value: Value,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    nonisolatedInstance(Value.self, value: value, qualifier: qualifier, fileID: fileID, line: line)
}

/// Registers an existing sendable value as a nonisolated singleton under an explicit service type.
///
/// - Parameters:
///   - type: The service type to register.
///   - value: The value supplied by the binding.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
/// - Returns: A singleton binding for the service.
public func nonisolatedInstance<Service: Sendable>(
    _ type: Service.Type,
    value: Service,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        isolation: .nonisolated,
        provider: .nonisolated { _ in value },
        source: .init(fileID: fileID, line: line),
        dependencies: []
    )
}

private func argumentMismatch(_ type: (some Any).Type, _ value: Any) -> SkeinError {
    .resolvedTypeMismatch(expected: String(reflecting: type), actual: String(reflecting: Swift.type(of: value)))
}
