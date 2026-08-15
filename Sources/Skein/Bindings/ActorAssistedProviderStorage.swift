/// Stores an assisted provider and the custom actor identity it must use.
package struct ActorAssistedProviderStorage: Sendable {
    /// The identity of the actor declared by the registration.
    package let expectedActorID: ObjectIdentifier
    /// The runtime isolation identity reported by the provider, when available.
    package let actualActorID: ObjectIdentifier?
    /// The diagnostic name of the declared actor.
    package let actorName: String
    /// Invokes the provider with a resolver and type-erased assisted argument.
    package let invoke: @Sendable (any Resolver, UncheckedProviderValue) async throws -> UncheckedProviderValue
}
