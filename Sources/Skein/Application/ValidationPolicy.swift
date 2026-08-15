/// Controls application startup validation.
public enum ValidationPolicy: Sendable {
    /// Validates all explicitly declared roots during application startup.
    case declaredRoots
}
