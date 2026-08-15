/// Builds the list of modules supplied to `startSkein`.
@resultBuilder public enum SkeinApplicationBuilder {
    /// Converts one module into a builder component.
    /// - Parameter expression: The module to include.
    /// - Returns: A one-element module array.
    public static func buildExpression(_ expression: Module) -> [Module] {
        [expression]
    }

    /// Uses an array of modules as a builder component.
    /// - Parameter expression: The modules to include.
    /// - Returns: The supplied module array.
    public static func buildExpression(_ expression: [Module]) -> [Module] {
        expression
    }

    /// Combines builder components in declaration order.
    /// - Parameter components: The module arrays to combine.
    /// - Returns: The flattened module array.
    public static func buildBlock(_ components: [Module]...) -> [Module] {
        components.flatMap(\.self)
    }

    /// Includes an optional builder component when present.
    /// - Parameter component: The optional module array.
    /// - Returns: The supplied modules, or an empty array when absent.
    public static func buildOptional(_ component: [Module]?) -> [Module] {
        component ?? []
    }

    /// Selects the first branch of a conditional builder expression.
    /// - Parameter component: The modules produced by the first branch.
    /// - Returns: The supplied module array.
    public static func buildEither(first component: [Module]) -> [Module] {
        component
    }

    /// Selects the second branch of a conditional builder expression.
    /// - Parameter component: The modules produced by the second branch.
    /// - Returns: The supplied module array.
    public static func buildEither(second component: [Module]) -> [Module] {
        component
    }

    /// Flattens builder components produced by a loop.
    /// - Parameter components: The module arrays produced by loop iterations.
    /// - Returns: The flattened module array.
    public static func buildArray(_ components: [[Module]]) -> [Module] {
        components.flatMap(\.self)
    }
}
