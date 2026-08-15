import Foundation

/// Identifies a scope by its kind and caller-provided identifier.
package struct ScopeIdentity: Hashable, @unchecked Sendable {
    /// The runtime identity of the scope kind.
    package let type: ObjectIdentifier

    /// The fully qualified name of the scope kind.
    package let typeName: String

    /// The type-erased identifier of the scope instance.
    package let id: AnyHashable

    /// A diagnostic description of the scope identifier.
    package let idDescription: String

    /// Creates a scope identity.
    ///
    /// - Parameters:
    ///   - type: The scope kind.
    ///   - id: The identifier for the scope instance.
    package init(type: (some SkeinScope).Type, id: some Hashable & Sendable) {
        self.type = ObjectIdentifier(type)
        typeName = String(reflecting: type)
        self.id = AnyHashable(id)
        idDescription = String(describing: id)
    }
}
