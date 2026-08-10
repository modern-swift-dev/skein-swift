/// A dependency registration. Create bindings through `single` or `factory`.
public struct Binding {
    package let key: BindingKey
    package let lifetime: BindingLifetime
    package let provider: (any Resolver) throws -> Any
}

/// Registers a lazily-created dependency shared by every successful resolution.
public func single<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    provider: @escaping (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        provider: { resolver in try provider(resolver) }
    )
}

/// Registers a dependency whose provider is invoked on every resolution.
public func factory<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    provider: @escaping (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .factory,
        provider: { resolver in try provider(resolver) }
    )
}
