package struct QualifierKey: Hashable, @unchecked Sendable {
    package let type: ObjectIdentifier
    package let typeName: String
    package let value: AnyHashable

    package init(_ qualifier: any SkeinQualifier) {
        type = ObjectIdentifier(Swift.type(of: qualifier))
        typeName = String(reflecting: Swift.type(of: qualifier))
        value = AnyHashable(qualifier)
    }

    package var description: String {
        "\(typeName).\(String(describing: value))"
    }
}
