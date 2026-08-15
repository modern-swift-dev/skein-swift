/// One dependency in a resolution trace.
public struct SkeinResolutionFrame: Equatable, Sendable {
    /// The fully qualified name of the requested service type.
    public let type: String
    /// The qualifier description, or `nil` for an unqualified binding.
    public let qualifier: String?
    /// The assisted argument type name, or `nil` for an ordinary binding.
    public let argumentType: String?
    /// The binding's registration location, when one is known.
    public let registration: SkeinSourceLocation?

    /// Creates a frame in a dependency resolution path.
    ///
    /// - Parameters:
    ///   - type: The fully qualified name of the requested service type.
    ///   - qualifier: The qualifier description, or `nil` for an unqualified binding.
    ///   - argumentType: The assisted argument type name, or `nil` for an ordinary binding.
    ///   - registration: The binding's registration location, when one is known.
    public init(
        type: String,
        qualifier: String?,
        argumentType: String?,
        registration: SkeinSourceLocation?
    ) {
        self.type = type
        self.qualifier = qualifier
        self.argumentType = argumentType
        self.registration = registration
    }
}
