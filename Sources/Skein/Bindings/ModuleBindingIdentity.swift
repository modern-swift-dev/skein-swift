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
    ///
    /// - Parameter overlay: The module whose matching bindings take precedence.
    /// - Returns: A module containing retained base bindings followed by overlay bindings.
    func overriding(_ overlay: Module) -> Module {
        let baseIdentities = Set(bindings.lazy.map(ModuleBindingIdentity.init))
        let overlayIdentities = Set(overlay.bindings.lazy.map(ModuleBindingIdentity.init))

        guard baseIdentities.count == bindings.count,
              overlayIdentities.count == overlay.bindings.count else {
            // Preserve invalid input so ordinary container validation still
            // reports duplicates within either source module.
            return Module(bindings: bindings + overlay.bindings)
        }

        let retainedBase = bindings.filter { !overlayIdentities.contains(ModuleBindingIdentity($0)) }
        return Module(bindings: retainedBase + overlay.bindings)
    }
}
