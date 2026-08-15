/// A binding reached by validation whose closure does not expose dependency
/// edges to Skein.
public struct OpaqueBinding: Equatable, Sendable {
    /// The fully qualified name of the bound service type.
    public let type: String
    /// The qualifier description, or `nil` for an unqualified binding.
    public let qualifier: String?
    /// The source location at which the binding was registered.
    public let registration: SkeinSourceLocation
    /// The isolation domain in which the provider executes.
    public let isolation: BindingIsolationDescription

    /// Creates a description of a binding whose dependencies are opaque.
    ///
    /// - Parameters:
    ///   - type: The fully qualified name of the bound service type.
    ///   - qualifier: The qualifier description, or `nil` for an unqualified binding.
    ///   - registration: The source location at which the binding was registered.
    ///   - isolation: The isolation domain in which the provider executes.
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
