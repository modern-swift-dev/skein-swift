private func mainActorDisposer<Service>(
    _ callback: (@MainActor (Service) async -> Void)?
) -> BindingDisposer? {
    callback.map { callback in
        .mainActor { value in
            guard let service = value.value as? Service else { return }
            await callback(service)
        }
    }
}

private func nonisolatedDisposer<Service: Sendable>(
    _ callback: (@Sendable (Service) async -> Void)?
) -> BindingDisposer? {
    callback.map { callback in
        .nonisolated { value in
            guard let service = value.value as? Service else { return }
            await callback(service)
        }
    }
}

// MARK: MainActor providers

@MainActor public func single<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier), lifetime: .single, isolation: .mainActor,
            provider: .mainActor { try provider($0) }, disposer: mainActorDisposer(onClose),
            source: .init(fileID: fileID, line: line))
}

@MainActor public func factory<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier), lifetime: .factory, isolation: .mainActor,
            provider: .mainActor { try provider($0) }, source: .init(fileID: fileID, line: line))
}

@MainActor public func factory<Service, Arguments>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver, Arguments) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier, argumentType: arguments), lifetime: .factory,
            isolation: .mainActor, provider: .mainActorAssisted { resolver, value in
                guard let arguments = value as? Arguments else { throw argumentMismatch(Arguments.self, value) }
                return try provider(resolver, arguments)
            }, source: .init(fileID: fileID, line: line))
}

@MainActor public func scoped<Service, Scope: SkeinScope>(
    _ type: Service.Type,
    scope: Scope.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier),
            lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
            isolation: .mainActor, provider: .mainActor { try provider($0) },
            disposer: mainActorDisposer(onClose), source: .init(fileID: fileID, line: line))
}

@MainActor public func scoped<Service, Scope: SkeinScope>(
    _ scope: Scope.Type,
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    scoped(type, scope: scope, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line, provider: provider)
}

@MainActor public func instance<Value>(
    _ value: Value,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    instance(Value.self, value: value, qualifier: qualifier, fileID: fileID, line: line)
}

@MainActor public func instance<Service>(
    _ type: Service.Type,
    value: Service,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier), lifetime: .single, isolation: .mainActor,
            provider: .mainActor { _ in value }, source: .init(fileID: fileID, line: line), dependencies: [])
}

// MARK: Nonisolated providers

public func nonisolatedSingle<Service: Sendable>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier), lifetime: .single, isolation: .nonisolated,
            provider: .nonisolated { try provider($0) }, disposer: nonisolatedDisposer(onClose),
            source: .init(fileID: fileID, line: line))
}

public func nonisolatedFactory<Service: Sendable>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier), lifetime: .factory, isolation: .nonisolated,
            provider: .nonisolated { try provider($0) }, source: .init(fileID: fileID, line: line))
}

public func nonisolatedFactory<Service: Sendable, Arguments: Sendable>(
    _ type: Service.Type,
    arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver, Arguments) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier, argumentType: arguments), lifetime: .factory,
            isolation: .nonisolated, provider: .nonisolatedAssisted { resolver, value in
                guard let arguments = value as? Arguments else { throw argumentMismatch(Arguments.self, value) }
                return try provider(resolver, arguments)
            }, source: .init(fileID: fileID, line: line))
}

public func nonisolatedScoped<Service: Sendable, Scope: SkeinScope>(
    _ type: Service.Type,
    scope: Scope.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier),
            lifetime: .scoped(type: ObjectIdentifier(scope), typeName: String(reflecting: scope)),
            isolation: .nonisolated, provider: .nonisolated { try provider($0) },
            disposer: nonisolatedDisposer(onClose), source: .init(fileID: fileID, line: line))
}

public func nonisolatedScoped<Service: Sendable, Scope: SkeinScope>(
    _ scope: Scope.Type,
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    provider: @escaping @Sendable (any Resolver) throws -> Service
) -> Binding {
    nonisolatedScoped(type, scope: scope, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line, provider: provider)
}

public func nonisolatedInstance<Value: Sendable>(
    _ value: Value,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    nonisolatedInstance(Value.self, value: value, qualifier: qualifier, fileID: fileID, line: line)
}

public func nonisolatedInstance<Service: Sendable>(
    _ type: Service.Type,
    value: Service,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line
) -> Binding {
    Binding(key: BindingKey(type, qualifier: qualifier), lifetime: .single, isolation: .nonisolated,
            provider: .nonisolated { _ in value }, source: .init(fileID: fileID, line: line), dependencies: [])
}

private func argumentMismatch<Arguments>(_ type: Arguments.Type, _ value: Any) -> SkeinError {
    .resolvedTypeMismatch(expected: String(reflecting: type), actual: String(reflecting: Swift.type(of: value)))
}
