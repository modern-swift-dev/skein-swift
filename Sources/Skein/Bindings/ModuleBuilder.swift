/// Builds a module from bindings and ordinary Swift control flow.
@resultBuilder public enum ModuleBuilder {
    /// Converts one binding into a builder component.
    /// - Parameter expression: The binding to include.
    /// - Returns: A one-element binding array.
    public static func buildExpression(_ expression: Binding) -> [Binding] {
        [expression]
    }

    /// Uses an array of bindings as a builder component.
    /// - Parameter expression: The bindings to include.
    /// - Returns: The supplied binding array.
    public static func buildExpression(_ expression: [Binding]) -> [Binding] {
        expression
    }

    /// Combines builder components in declaration order.
    /// - Parameter components: The binding arrays to combine.
    /// - Returns: The flattened binding array.
    public static func buildBlock(_ components: [Binding]...) -> [Binding] {
        components.flatMap(\.self)
    }

    /// Includes an optional builder component when present.
    /// - Parameter component: The optional binding array.
    /// - Returns: The supplied bindings, or an empty array when absent.
    public static func buildOptional(_ component: [Binding]?) -> [Binding] {
        component ?? []
    }

    /// Selects the first branch of a conditional builder expression.
    /// - Parameter component: The bindings produced by the first branch.
    /// - Returns: The supplied binding array.
    public static func buildEither(first component: [Binding]) -> [Binding] {
        component
    }

    /// Selects the second branch of a conditional builder expression.
    /// - Parameter component: The bindings produced by the second branch.
    /// - Returns: The supplied binding array.
    public static func buildEither(second component: [Binding]) -> [Binding] {
        component
    }

    /// Flattens builder components produced by a loop.
    /// - Parameter components: The binding arrays produced by loop iterations.
    /// - Returns: The flattened binding array.
    public static func buildArray(_ components: [[Binding]]) -> [Binding] {
        components.flatMap(\.self)
    }
}
