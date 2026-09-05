/// A type-erased, hashable qualifier identity.
package struct QualifierKey: Hashable, @unchecked Sendable {
    private let qualifierType: Any.Type

    /// The concrete qualifier type identity.
    package var type: ObjectIdentifier {
        ObjectIdentifier(qualifierType)
    }

    /// The concrete qualifier type name used in diagnostics.
    package var typeName: String {
        String(reflecting: qualifierType)
    }

    /// The type-erased qualifier value.
    package let value: AnyHashable

    /// Creates a key from a qualifier value.
    ///
    /// - Parameter qualifier: The qualifier to erase.
    package init(_ qualifier: any SkeinQualifier) {
        qualifierType = Swift.type(of: qualifier)
        value = AnyHashable(qualifier)
    }

    /// Compares the concrete qualifier type and value.
    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.value == rhs.value
    }

    /// Hashes the concrete qualifier type and value.
    ///
    /// - Parameter hasher: The hasher receiving the qualifier identity.
    package func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(value)
    }

    /// A diagnostic description containing the qualifier type and value.
    package var description: String {
        "\(typeName).\(String(describing: value))"
    }
}
