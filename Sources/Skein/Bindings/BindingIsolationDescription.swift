/// Public, stable description of where a binding executes.
public enum BindingIsolationDescription: Equatable, Hashable, Sendable {
    /// Main-actor isolation.
    case mainActor
    /// No actor isolation.
    case nonisolated
    /// Isolation to the named custom global actor.
    case customActor(String)
}
