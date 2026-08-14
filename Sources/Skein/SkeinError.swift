/// Errors produced by the Skein container itself. Resolution APIs expose these
/// as the `underlying` cause of a ``SkeinResolutionError``.
public enum SkeinError: Error, Equatable, Sendable {
    case notStarted
    case alreadyStarted
    case duplicateBinding(type: String, qualifier: String?)
    case missingBinding(type: String, qualifier: String?)
    /// An ordinary `get` attempted to resolve a main-actor binding.
    case mainActorBindingRequiresMainActor(type: String, qualifier: String?)
    case circularDependency(path: [String])
    case resolvedTypeMismatch(expected: String, actual: String)
    case applicationClosed
    case duplicateScope(scope: String, id: String)
    case scopeClosed(scope: String, id: String)
}
