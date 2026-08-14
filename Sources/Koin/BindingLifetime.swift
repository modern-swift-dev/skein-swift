package enum BindingLifetime: Sendable {
    case single
    case factory
    case scoped(type: ObjectIdentifier, typeName: String)

    package var isRoot: Bool {
        switch self {
            case .single,
                 .factory: true
            case .scoped: false
        }
    }
}
