/// A type-erased disposal callback and its required isolation.
package enum BindingDisposer {
    /// A disposer that runs on the main actor.
    case mainActor(@MainActor (UncheckedProviderValue) async -> Void)
    /// A sendable disposer that runs without actor isolation.
    case nonisolated(@Sendable (UncheckedProviderValue) async -> Void)
    /// A disposer that runs on a custom global actor.
    case customActor(ActorDisposerStorage)
}
