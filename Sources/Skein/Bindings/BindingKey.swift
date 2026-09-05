/// Identifies a registration by service, qualifier, and assisted argument type.
package struct BindingKey: Hashable, Sendable {
    private let serviceType: Any.Type
    private let assistedArgumentType: Any.Type?

    /// The registered service type identity.
    package var type: ObjectIdentifier {
        ObjectIdentifier(serviceType)
    }

    /// The registered service type name used in diagnostics.
    package var typeName: String {
        String(reflecting: serviceType)
    }

    /// The qualifier identity, if the registration is qualified.
    package let qualifier: QualifierKey?
    /// The assisted argument type identity, if required.
    package var argumentType: ObjectIdentifier? {
        assistedArgumentType.map(ObjectIdentifier.init)
    }

    /// The assisted argument type name used in diagnostics, if required.
    package var argumentTypeName: String? {
        assistedArgumentType.map { String(reflecting: $0) }
    }

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
        self.init(anyType: type, qualifier: qualifier, argumentType: argumentType)
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
        serviceType = anyType
        self.qualifier = qualifier.map(QualifierKey.init)
        assistedArgumentType = argumentType
    }

    /// Compares lookup identities without constructing diagnostic names.
    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.qualifier == rhs.qualifier && lhs.argumentType == rhs.argumentType
    }

    /// Hashes the service, qualifier, and assisted argument identities.
    ///
    /// - Parameter hasher: The hasher receiving the lookup identity.
    package func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(qualifier)
        hasher.combine(argumentType)
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
