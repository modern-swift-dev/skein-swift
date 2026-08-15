/// A structural graph violation found without executing a provider.
public enum GraphValidationError: Error, Equatable, Sendable {
    /// A dependency path reaches a type and qualifier with no registered binding.
    case missingBinding(type: String, qualifier: String?, path: [String])
    /// A dependency path contains a cycle.
    case circularDependency(path: [String])
    /// A parent binding cannot depend on a binding with the reported isolation.
    case isolationMismatch(
        path: [String],
        parent: BindingIsolationDescription,
        dependency: BindingIsolationDescription
    )
    /// An application-lifetime root depends on a scoped binding.
    case rootDependsOnScopedBinding(path: [String], scope: String)
    /// A binding in one scope depends on a binding in a different scope.
    case crossScopeDependency(path: [String], from: String, to: String)
}
