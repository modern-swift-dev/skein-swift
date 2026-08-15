/// Stores a disposer and the custom actor identity it must use.
package struct ActorDisposerStorage: Sendable {
    /// The identity of the actor declared by the registration.
    package let expectedActorID: ObjectIdentifier
    /// The runtime isolation identity reported by the disposer, when available.
    package let actualActorID: ObjectIdentifier?
    /// The diagnostic name of the declared actor.
    package let actorName: String
    /// Invokes the disposer with a type-erased service value.
    package let invoke: @Sendable (UncheckedProviderValue) async -> Void
}
