/// Describes the execution isolation required by a binding.
package enum BindingIsolation: Hashable, Sendable {
    /// Main-actor isolation.
    case mainActor
    /// No actor isolation.
    case nonisolated
    /// Isolation to the identified custom global actor.
    case customActor(id: ObjectIdentifier, name: String)

    /// The stable public description of this isolation.
    package var description: BindingIsolationDescription {
        switch self {
            case .mainActor: .mainActor
            case .nonisolated: .nonisolated
            case let .customActor(_, name): .customActor(name)
        }
    }
}
