/// Determines how a declared application root is checked at startup.
public enum RootPolicy: Equatable, Hashable, Sendable {
    /// Checks the root's declared dependency graph without executing providers.
    case structural
    /// Resolves the root at startup after its dependency graph passes structural validation.
    case eager
}
