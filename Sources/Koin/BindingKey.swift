package struct BindingKey: Hashable, Sendable {
    package let type: ObjectIdentifier
    package let typeName: String
    package let qualifier: QualifierKey?

    package init(_ type: (some Any).Type, qualifier: (any KoinQualifier)?) {
        self.type = ObjectIdentifier(type)
        self.typeName = String(reflecting: type)
        self.qualifier = qualifier.map(QualifierKey.init)
    }

    package var description: String {
        guard let qualifier else {
            return typeName
        }
        return "\(typeName) [\(qualifier.description)]"
    }
}
