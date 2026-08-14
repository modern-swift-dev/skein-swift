/// Builds the list of modules supplied to `startSkein`.
@resultBuilder public enum SkeinApplicationBuilder {
    public static func buildBlock(_ components: [Module]...) -> [Module] {
        components.flatMap(\.self)
    }
}

/// Makes modules available to the surrounding `startSkein` builder.
public func modules(_ modules: Module...) -> [Module] {
    modules
}
