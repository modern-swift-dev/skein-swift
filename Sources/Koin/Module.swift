/// A group of dependency bindings.
public struct Module {
    package let bindings: [Binding]

    public init(@ModuleBuilder _ content: () -> [Binding]) {
        bindings = content()
    }
}

/// Creates a module containing its declared bindings.
public func module(@ModuleBuilder _ content: () -> [Binding]) -> Module {
    Module(content)
}
