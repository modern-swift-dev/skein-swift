/// A dependency registration. Create bindings through `single`, `factory`,
/// `scoped`, and their main-actor variants.
public struct Binding {
    package let key: BindingKey
    package let lifetime: BindingLifetime
    package let provider: BindingProvider
    package let disposer: BindingDisposer?
    package let source: KoinSourceLocation
    /// `nil` means the provider is opaque; an empty array is a known leaf.
    package let dependencies: [BindingDependency]?

    package init(
        key: BindingKey,
        lifetime: BindingLifetime,
        provider: BindingProvider,
        disposer: BindingDisposer? = nil,
        source: KoinSourceLocation = KoinSourceLocation(fileID: "<unknown>", line: 0),
        dependencies: [BindingDependency]? = nil
    ) {
        self.key = key
        self.lifetime = lifetime
        self.provider = provider
        self.disposer = disposer
        self.source = source
        self.dependencies = dependencies
    }
}

package enum BindingProvider {
    case standard((any Resolver) throws -> Any)
    case mainActor(@MainActor (any Resolver) throws -> Any)
    case standardAssisted((any Resolver, Any) throws -> Any)
    case mainActorAssisted(@MainActor (any Resolver, Any) throws -> Any)
}

package enum BindingDisposer {
    case standard((Any) async -> Void)
    case mainActor(@MainActor (UncheckedDisposalValue) async -> Void)
}

package struct UncheckedDisposalValue: @unchecked Sendable {
    package let value: Any
}

/// Registers a lazily-created dependency shared by every successful resolution.
public func single<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        provider: .standard { resolver in try provider(resolver) },
        disposer: onClose.map { callback in
            .standard { value in
                guard let service = value as? Service else {
                    return
                }
                await callback(service)
            }
        },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a dependency whose provider is invoked on every resolution.
public func factory<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .factory,
        provider: .standard { resolver in try provider(resolver) },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a factory that receives one strongly typed assisted argument.
public func factory<Service, Arguments>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    qualifier: (any KoinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping (any Resolver, Arguments) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier, argumentType: arguments),
        lifetime: .factory,
        provider: .standardAssisted { resolver, value in
            guard let arguments = value as? Arguments else {
                throw KoinError.resolvedTypeMismatch(
                    expected: String(reflecting: Arguments.self),
                    actual: String(reflecting: Swift.type(of: value))
                )
            }
            return try provider(resolver, arguments)
        },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a lazily-created main-actor dependency.
public func mainActorSingle<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        provider: .mainActor { resolver in try provider(resolver) },
        disposer: onClose.map { callback in
            .mainActor { value in
                guard let service = value.value as? Service else {
                    return
                }
                await callback(service)
            }
        },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a main-actor dependency created on every resolution.
public func mainActorFactory<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .factory,
        provider: .mainActor { resolver in try provider(resolver) },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a main-actor factory with one strongly typed assisted argument.
public func mainActorFactory<Service, Arguments>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    qualifier: (any KoinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver, Arguments) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier, argumentType: arguments),
        lifetime: .factory,
        provider: .mainActorAssisted { resolver, value in
            guard let arguments = value as? Arguments else {
                throw KoinError.resolvedTypeMismatch(
                    expected: String(reflecting: Arguments.self),
                    actual: String(reflecting: Swift.type(of: value))
                )
            }
            return try provider(resolver, arguments)
        },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a dependency cached once per active scope of `Kind`.
public func scoped<Service>(
    _ type: Service.Type,
    scope: (some KoinScope).Type,
    qualifier: (any KoinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
        provider: .standard { resolver in try provider(resolver) },
        disposer: onClose.map { callback in
            .standard { value in
                guard let service = value as? Service else {
                    return
                }
                await callback(service)
            }
        },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a dependency cached once per active scope of `Kind`.
public func scoped<Service>(
    _ scope: (some KoinScope).Type,
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping (any Resolver) throws -> Service
) -> Binding {
    scoped(
        type,
        scope: scope,
        qualifier: qualifier,
        onClose: onClose,
        fileID: fileID,
        line: line,
        provider: provider
    )
}

/// Registers a main-actor dependency cached once per active scope of `Kind`.
public func mainActorScoped<Service>(
    _ type: Service.Type,
    scope: (some KoinScope).Type,
    qualifier: (any KoinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
        provider: .mainActor { resolver in try provider(resolver) },
        disposer: onClose.map { callback in
            .mainActor { value in
                guard let service = value.value as? Service else {
                    return
                }
                await callback(service)
            }
        },
        source: KoinSourceLocation(fileID: fileID, line: line)
    )
}

/// Registers a main-actor dependency cached once per active scope of `Kind`.
public func mainActorScoped<Service>(
    _ scope: (some KoinScope).Type,
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    mainActorScoped(
        type,
        scope: scope,
        qualifier: qualifier,
        onClose: onClose,
        fileID: fileID,
        line: line,
        provider: provider
    )
}
