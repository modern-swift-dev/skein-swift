/// Identifies a registration by service, qualifier, and assisted argument type.
package struct BindingKey: Hashable, Sendable {
    /// The registered service type identity.
    package let type: ObjectIdentifier
    /// The registered service type name used in diagnostics.
    package let typeName: String
    /// The qualifier identity, if the registration is qualified.
    package let qualifier: QualifierKey?
    /// The assisted argument type identity, if required.
    package let argumentType: ObjectIdentifier?
    /// The assisted argument type name used in diagnostics, if required.
    package let argumentTypeName: String?

    /// Creates a binding key from a statically known service type.
    ///
    /// - Parameters:
    ///   - type: The registered service type.
    ///   - qualifier: The qualifier, or `nil` for an unqualified binding.
    ///   - argumentType: The assisted argument type, or `nil` when none is required.
    package init(
        _ type: (some Any).Type,
        qualifier: (any SkeinQualifier)?,
        argumentType: Any.Type? = nil
    ) {
        self.type = ObjectIdentifier(type)
        self.typeName = String(reflecting: type)
        self.qualifier = qualifier.map(QualifierKey.init)
        self.argumentType = argumentType.map(ObjectIdentifier.init)
        self.argumentTypeName = argumentType.map { String(reflecting: $0) }
    }

    /// Creates a binding key from a type-erased service type.
    ///
    /// - Parameters:
    ///   - anyType: The registered service type.
    ///   - qualifier: The qualifier, or `nil` for an unqualified binding.
    ///   - argumentType: The assisted argument type, or `nil` when none is required.
    package init(
        anyType: Any.Type,
        qualifier: (any SkeinQualifier)? = nil,
        argumentType: Any.Type? = nil
    ) {
        type = ObjectIdentifier(anyType)
        typeName = String(reflecting: anyType)
        self.qualifier = qualifier.map(QualifierKey.init)
        self.argumentType = argumentType.map(ObjectIdentifier.init)
        argumentTypeName = argumentType.map { String(reflecting: $0) }
    }

    /// A diagnostic description of the service, argument, and qualifier.
    package var description: String {
        var result = typeName
        if let argumentTypeName {
            result += " (arguments: \(argumentTypeName))"
        }
        if let qualifier {
            result += " [\(qualifier.description)]"
        }
        return result
    }
}
