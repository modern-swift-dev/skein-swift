/// Builds the list of modules supplied to `startKoin`.
@resultBuilder public enum KoinApplicationBuilder {
    public static func buildBlock(_ components: [Module]...) -> [Module] {
        components.flatMap(\.self)
    }
}

/// Makes modules available to the surrounding `startKoin` builder.
public func modules(_ modules: Module...) -> [Module] {
    modules
}
