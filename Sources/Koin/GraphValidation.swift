/// A typed root from which structural graph validation begins.
public struct ValidationRoot: Sendable {
    package let key: BindingKey
    public let source: KoinSourceLocation

    public init(
        _ type: (some Any).Type,
        qualifier: (any KoinQualifier)? = nil,
        fileID: String = #fileID,
        line: UInt = #line
    ) {
        key = BindingKey(type, qualifier: qualifier)
        source = KoinSourceLocation(fileID: fileID, line: line)
    }

    package init(anyType: Any.Type, source: KoinSourceLocation) {
        key = BindingKey(anyType: anyType)
        self.source = source
    }
}

/// A binding reached by validation whose closure does not expose dependency
/// edges to Koin.
public struct OpaqueBinding: Equatable, Sendable {
    public let type: String
    public let qualifier: String?
    public let registration: KoinSourceLocation
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
    case mainActorDependencyRequiresMainActor(path: [String])
    case rootDependsOnScopedBinding(path: [String], scope: String)
    case crossScopeDependency(path: [String], from: String, to: String)
}

package struct BindingDependency: Hashable, Sendable {
    package let key: BindingKey

    package init(_ type: (some Any).Type) {
        key = BindingKey(type, qualifier: nil)
    }
}
