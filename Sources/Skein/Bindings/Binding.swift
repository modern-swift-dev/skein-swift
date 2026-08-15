/// A dependency registration created by one of Skein's registration functions.
public struct Binding {
    /// The lookup key for the registered service.
    package let key: BindingKey
    /// The caching lifetime of the service.
    package let lifetime: BindingLifetime
    /// The isolation on which the provider executes.
    package let isolation: BindingIsolation
    /// The type-erased provider callback.
    package let provider: BindingProvider
    /// The optional type-erased disposal callback.
    package let disposer: BindingDisposer?
    /// The source location of the registration.
    package let source: SkeinSourceLocation
    /// `nil` means opaque; an empty array means a known leaf.
    package let dependencies: [BindingDependency]?
    /// The validation policy when this binding is an application root.
    package let rootPolicy: RootPolicy?
    /// The source location at which this binding was declared a root.
    package let rootSource: SkeinSourceLocation?

    /// Creates a dependency binding.
    ///
    /// - Parameters:
    ///   - key: The lookup key for the service.
    ///   - lifetime: The caching lifetime of the service.
    ///   - isolation: The isolation on which the provider executes.
    ///   - provider: The type-erased provider callback.
    ///   - disposer: The optional disposal callback.
    ///   - source: The source location of the registration.
    ///   - dependencies: The known dependency edges, or `nil` for an opaque provider.
    ///   - rootPolicy: The validation policy when the binding is a root.
    ///   - rootSource: The source location at which the binding was declared a root.
    package init(
        key: BindingKey,
        lifetime: BindingLifetime,
        isolation: BindingIsolation,
        provider: BindingProvider,
        disposer: BindingDisposer? = nil,
        source: SkeinSourceLocation = .init(fileID: "<unknown>", line: 0),
        dependencies: [BindingDependency]? = nil,
        rootPolicy: RootPolicy? = nil,
        rootSource: SkeinSourceLocation? = nil
    ) {
        self.key = key
        self.lifetime = lifetime
        self.isolation = isolation
        self.provider = provider
        self.disposer = disposer
        self.source = source
        self.dependencies = dependencies
        self.rootPolicy = rootPolicy
        self.rootSource = rootSource
    }

    /// Declares this binding as a structural or eager application root.
    ///
    /// - Parameters:
    ///   - policy: The validation policy to apply to the root.
    ///   - fileID: The source file containing the declaration.
    ///   - line: The source line containing the declaration.
    /// - Returns: A copy of the binding marked as an application root.
    public func root(
        _ policy: RootPolicy = .structural,
        fileID: String = #fileID,
        line: UInt = #line
    ) -> Binding {
        Binding(
            key: key,
            lifetime: lifetime,
            isolation: isolation,
            provider: provider,
            disposer: disposer,
            source: source,
            dependencies: dependencies,
            rootPolicy: policy,
            rootSource: .init(fileID: fileID, line: line)
        )
    }
}
