/// A group of dependency bindings.
public struct Module {
    package let bindings: [Binding]
    package let validationRoots: [ValidationRoot]

    public init(@ModuleBuilder _ content: () -> [Binding]) {
        bindings = content()
        validationRoots = []
    }

    package init(bindings: [Binding], validationRoots: [ValidationRoot]) {
        self.bindings = bindings
        self.validationRoots = validationRoots
    }

    /// Returns a copy of this module with an additional structural validation root.
    public func validating(
        _ type: (some Any).Type,
        qualifier: (any KoinQualifier)? = nil,
        fileID: String = #fileID,
        line: UInt = #line
    ) -> Module {
        validating(ValidationRoot(type, qualifier: qualifier, fileID: fileID, line: line))
    }

    /// Returns a copy of this module with an additional typed validation root.
    public func validating(_ root: ValidationRoot) -> Module {
        Module(bindings: bindings, validationRoots: validationRoots + [root])
    }

    /// Returns a copy with multiple unqualified validation roots.
    public func validating(
        _ types: Any.Type...,
        fileID: String = #fileID,
        line: UInt = #line
    ) -> Module {
        let source = KoinSourceLocation(fileID: fileID, line: line)
        return Module(
            bindings: bindings,
            validationRoots: validationRoots + types.map {
                ValidationRoot(anyType: $0, source: source)
            }
        )
    }
}

/// Creates a module containing its declared bindings.
public func module(@ModuleBuilder _ content: () -> [Binding]) -> Module {
    Module(content)
}
