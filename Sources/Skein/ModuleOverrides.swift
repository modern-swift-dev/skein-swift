private struct ModuleBindingIdentity: Hashable {
    let key: BindingKey
    let scopeType: ObjectIdentifier?

    init(_ binding: Binding) {
        key = binding.key
        if case let .scoped(type, _) = binding.lifetime {
            scopeType = type
        } else {
            scopeType = nil
        }
    }
}

public extension Module {
    /// Returns a new module in which overlay bindings replace exact matches.
    /// Both input modules remain unchanged.
    func overriding(_ overlay: Module) -> Module {
        let baseIdentities = bindings.map(ModuleBindingIdentity.init)
        let overlayIdentities = overlay.bindings.map(ModuleBindingIdentity.init)

        guard Set(baseIdentities).count == baseIdentities.count,
              Set(overlayIdentities).count == overlayIdentities.count else {
            // Preserve invalid input so ordinary container validation still
            // reports duplicates within either source module.
            return Module(bindings: bindings + overlay.bindings)
        }

        let replaced = Set(overlayIdentities)
        let retainedBase = bindings.filter { !replaced.contains(ModuleBindingIdentity($0)) }
        return Module(bindings: retainedBase + overlay.bindings)
    }
}
