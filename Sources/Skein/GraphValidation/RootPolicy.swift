/// Determines how a declared root is checked at startup.
public enum RootPolicy: Equatable, Hashable, Sendable {
    /// Checks the root's declared dependency graph without executing providers.
    ///
    /// This is the only policy available to scoped bindings, which are validated as scope roots.
    case structural
    /// Resolves the root at startup after its dependency graph passes structural validation.
    ///
    /// Only single and factory bindings may be eager roots.
    case eager
}
