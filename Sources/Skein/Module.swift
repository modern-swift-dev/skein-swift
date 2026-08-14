/// A group of dependency bindings.
public struct Module {
    package let bindings: [Binding]

    @MainActor public init(@ModuleBuilder _ content: () -> [Binding]) {
        bindings = content()
    }

    package init(bindings: [Binding]) {
        self.bindings = bindings
    }
}

/// Creates a module containing its declared bindings.
@MainActor public func module(@ModuleBuilder _ content: () -> [Binding]) -> Module {
    Module(content)
}
