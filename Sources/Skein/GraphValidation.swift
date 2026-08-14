/// Determines how a declared application root is checked at startup.
public enum RootPolicy: Equatable, Hashable, Sendable {
    case structural
    case eager
}

/// A binding reached by validation whose closure does not expose dependency
/// edges to Skein.
public struct OpaqueBinding: Equatable, Sendable {
    public let type: String
    public let qualifier: String?
    public let registration: SkeinSourceLocation
    public let isolation: BindingIsolationDescription

    public init(
        type: String,
        qualifier: String?,
        registration: SkeinSourceLocation,
        isolation: BindingIsolationDescription
    ) {
        self.type = type
        self.qualifier = qualifier
        self.registration = registration
        self.isolation = isolation
    }
}

/// The result of successfully validating every declared root.
public struct GraphValidationReport: Equatable, Sendable {
    public let opaqueBindings: [OpaqueBinding]

    public init(opaqueBindings: [OpaqueBinding]) {
        self.opaqueBindings = opaqueBindings
    }
}

/// A structural graph violation found without executing a provider.
public enum GraphValidationError: Error, Equatable, Sendable {
    case missingBinding(type: String, qualifier: String?, path: [String])
    case circularDependency(path: [String])
    case isolationMismatch(
        path: [String],
        parent: BindingIsolationDescription,
        dependency: BindingIsolationDescription
    )
    case rootDependsOnScopedBinding(path: [String], scope: String)
    case crossScopeDependency(path: [String], from: String, to: String)
}
