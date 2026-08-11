/// A dependency registration. Create bindings through `single`, `factory`,
/// `mainActorSingle`, or `mainActorFactory`.
public struct Binding {
    package let key: BindingKey
    package let lifetime: BindingLifetime
    package let provider: BindingProvider
}

package enum BindingProvider {
    case standard((any Resolver) throws -> Any)
    case mainActor(@MainActor (any Resolver) throws -> Any)
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
        provider: .standard { resolver in try provider(resolver) }
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
        provider: .standard { resolver in try provider(resolver) }
    )
}

/// Registers a lazily-created main-actor dependency shared by every successful
/// `mainActorGet` resolution.
///
/// The provider runs on the main actor. Dependencies that are themselves
/// main-actor bindings must be resolved through `Resolver.mainActorGet`.
public func mainActorSingle<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .single,
        provider: .mainActor { resolver in try provider(resolver) }
    )
}

/// Registers a main-actor dependency whose provider is invoked on every
/// `mainActorGet` resolution.
///
/// The provider runs on the main actor. Dependencies that are themselves
/// main-actor bindings must be resolved through `Resolver.mainActorGet`.
public func mainActorFactory<Service>(
    _ type: Service.Type,
    qualifier: (any KoinQualifier)? = nil,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: .factory,
        provider: .mainActor { resolver in try provider(resolver) }
    )
}
