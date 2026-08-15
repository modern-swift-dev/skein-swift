/// Identifies a dependency edge declared by a binding.
package struct BindingDependency: Hashable, Sendable {
    /// The key of the required binding.
    package let key: BindingKey

    /// Creates a dependency for an unqualified service type.
    ///
    /// - Parameter type: The required service type.
    package init(_ type: (some Any).Type) {
        key = BindingKey(type, qualifier: nil)
    }
}
