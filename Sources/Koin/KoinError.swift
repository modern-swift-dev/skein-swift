/// Errors produced by the Koin container itself. Errors thrown by providers are
/// propagated without being wrapped.
public enum KoinError: Error, Equatable, Sendable {
    case notStarted
    case alreadyStarted
    case duplicateBinding(type: String, qualifier: String?)
    case missingBinding(type: String, qualifier: String?)
    case circularDependency(path: [String])
    case resolvedTypeMismatch(expected: String, actual: String)
}
