/// Builds the list of modules supplied to `startSkein`.
@resultBuilder public enum SkeinApplicationBuilder {
    public static func buildExpression(_ expression: Module) -> [Module] { [expression] }
    public static func buildExpression(_ expression: [Module]) -> [Module] { expression }
    public static func buildBlock(_ components: [Module]...) -> [Module] {
        components.flatMap(\.self)
    }
    public static func buildOptional(_ component: [Module]?) -> [Module] { component ?? [] }
    public static func buildEither(first component: [Module]) -> [Module] { component }
    public static func buildEither(second component: [Module]) -> [Module] { component }
    public static func buildArray(_ components: [[Module]]) -> [Module] { components.flatMap(\.self) }
}
