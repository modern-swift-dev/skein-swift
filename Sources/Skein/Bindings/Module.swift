/// A group of dependency bindings.
public struct Module {
    /// The bindings declared by this module.
    package let bindings: [Binding]

    /// Creates a module from a main-actor-isolated binding builder.
    ///
    /// - Parameter content: The builder that declares the module's bindings.
    @MainActor public init(@ModuleBuilder _ content: () -> [Binding]) {
        bindings = content()
    }

    /// Creates a module from an existing binding array.
    ///
    /// - Parameter bindings: The bindings to include.
    package init(bindings: [Binding]) {
        self.bindings = bindings
    }
}

/// Creates a module containing its declared bindings.
///
/// - Parameter content: The builder that declares the module's bindings.
/// - Returns: A module containing the built bindings.
@MainActor public func module(@ModuleBuilder _ content: () -> [Binding]) -> Module {
    Module(content)
}
