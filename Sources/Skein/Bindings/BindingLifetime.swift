/// The caching lifetime of a binding.
package enum BindingLifetime: Sendable {
    /// One value shared by the application.
    case single
    /// A new value for each resolution.
    case factory
    /// One value per instance of the identified scope type.
    case scoped(type: ObjectIdentifier, typeName: String)

    /// Whether the lifetime can serve as an application-level root.
    package var isRoot: Bool {
        switch self {
            case .single,
                 .factory: true
            case .scoped: false
        }
    }
}
