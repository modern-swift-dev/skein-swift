/// A type-erased, hashable qualifier identity.
package struct QualifierKey: Hashable, @unchecked Sendable {
    /// The concrete qualifier type identity.
    package let type: ObjectIdentifier
    /// The concrete qualifier type name used in diagnostics.
    package let typeName: String
    /// The type-erased qualifier value.
    package let value: AnyHashable

    /// Creates a key from a qualifier value.
    ///
    /// - Parameter qualifier: The qualifier to erase.
    package init(_ qualifier: any SkeinQualifier) {
        type = ObjectIdentifier(Swift.type(of: qualifier))
        typeName = String(reflecting: Swift.type(of: qualifier))
        value = AnyHashable(qualifier)
    }

    /// A diagnostic description containing the qualifier type and value.
    package var description: String {
        "\(typeName).\(String(describing: value))"
    }
}
