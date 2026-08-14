/// Builds a module from bindings and ordinary Swift control flow.
@resultBuilder public enum ModuleBuilder {
    public static func buildExpression(_ expression: Binding) -> [Binding] { [expression] }
    public static func buildExpression(_ expression: [Binding]) -> [Binding] { expression }
    public static func buildBlock(_ components: [Binding]...) -> [Binding] { components.flatMap(\.self) }
    public static func buildOptional(_ component: [Binding]?) -> [Binding] { component ?? [] }
    public static func buildEither(first component: [Binding]) -> [Binding] { component }
    public static func buildEither(second component: [Binding]) -> [Binding] { component }
    public static func buildArray(_ components: [[Binding]]) -> [Binding] { components.flatMap(\.self) }
}
