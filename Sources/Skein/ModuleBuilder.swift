/// Builds a module from a straight list of `single` and `factory` bindings.
@resultBuilder public enum ModuleBuilder {
    public static func buildBlock(_ components: Binding...) -> [Binding] {
        components
    }
}
