package struct BindingKey: Hashable, Sendable {
    package let type: ObjectIdentifier
    package let typeName: String
    package let qualifier: QualifierKey?
    package let argumentType: ObjectIdentifier?
    package let argumentTypeName: String?

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
