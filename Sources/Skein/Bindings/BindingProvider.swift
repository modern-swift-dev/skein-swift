/// A type-erased provider and its required isolation.
package enum BindingProvider {
    /// A main-actor provider without assisted arguments.
    case mainActor(@MainActor (any Resolver) throws -> Any)
    /// A main-actor provider with a type-erased assisted argument.
    case mainActorAssisted(@MainActor (any Resolver, Any) throws -> Any)
    /// A sendable provider without actor isolation or assisted arguments.
    case nonisolated(@Sendable (any Resolver) throws -> Any)
    /// A sendable provider with a type-erased assisted argument.
    case nonisolatedAssisted(@Sendable (any Resolver, Any) throws -> Any)
    /// A provider isolated to a custom global actor.
    case customActor(ActorProviderStorage)
    /// An assisted provider isolated to a custom global actor.
    case customActorAssisted(ActorAssistedProviderStorage)
}
