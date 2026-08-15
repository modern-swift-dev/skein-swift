/// Errors produced by the Skein container itself. Resolution APIs expose these
/// as the `underlying` cause of a ``SkeinResolutionError``.
public enum SkeinError: Error, Equatable, Sendable {
    /// The global Skein application has not been started.
    case notStarted
    /// The global Skein application has already been started.
    case alreadyStarted
    /// More than one binding was registered for the same type and qualifier.
    case duplicateBinding(type: String, qualifier: String?)
    /// No binding matches the requested type and qualifier.
    case missingBinding(type: String, qualifier: String?)
    /// A binding cannot be resolved from the requested isolation domain.
    case bindingIsolationMismatch(type: String, qualifier: String?, required: String, actual: String)
    /// A dynamically registered actor does not match the actor required by the binding.
    case actorIsolationMismatch(type: String, qualifier: String?, expected: String, actual: String?)
    /// A scoped binding was declared as an application root.
    case scopedBindingCannotBeRoot(type: String, qualifier: String?)
    /// An assisted binding was declared as an eager application root.
    case eagerAssistedRoot(type: String, qualifier: String?)
    /// Resolution encountered a dependency cycle along the supplied path.
    case circularDependency(path: [String])
    /// A provider returned a value whose type differs from the registered service type.
    case resolvedTypeMismatch(expected: String, actual: String)
    /// The application was used after it began closing or had closed.
    case applicationClosed
    /// A scope with the same kind and identifier is already active.
    case duplicateScope(scope: String, id: String)
    /// The scope was used after it began closing or had closed.
    case scopeClosed(scope: String, id: String)
}
