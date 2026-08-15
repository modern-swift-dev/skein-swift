struct ValidationNodeIdentity: Hashable {
    let key: BindingKey
    let scopeType: ObjectIdentifier?

    init(key: BindingKey, lifetime: BindingLifetime) {
        self.key = key
        if case let .scoped(type, _) = lifetime {
            scopeType = type
        } else {
            scopeType = nil
        }
    }
}
