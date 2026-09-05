import Foundation

/// Identifies a scope by its kind and caller-provided identifier.
package struct ScopeIdentity: Hashable, @unchecked Sendable {
    private let scopeType: any SkeinScope.Type

    /// The runtime identity of the scope kind.
    package var type: ObjectIdentifier {
        ObjectIdentifier(scopeType)
    }

    /// The fully qualified name of the scope kind.
    package var typeName: String {
        String(reflecting: scopeType)
    }

    /// The type-erased identifier of the scope instance.
    package let id: AnyHashable

    /// A diagnostic description of the scope identifier.
    package var idDescription: String {
        String(describing: id.base)
    }

    /// Creates a scope identity.
    ///
    /// - Parameters:
    ///   - type: The scope kind.
    ///   - id: The identifier for the scope instance.
    package init(type: (some SkeinScope).Type, id: some Hashable & Sendable) {
        scopeType = type
        self.id = AnyHashable(id)
    }

    /// Compares the scope kind and identifier without formatting diagnostics.
    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.type == rhs.type && lhs.id == rhs.id
    }

    /// Hashes the scope kind and identifier.
    ///
    /// - Parameter hasher: The hasher receiving the scope identity.
    package func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(id)
    }
}
