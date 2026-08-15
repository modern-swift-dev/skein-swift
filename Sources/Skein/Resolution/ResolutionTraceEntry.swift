/// Describes one binding in an active dependency-resolution path.
package struct ResolutionTraceEntry: @unchecked Sendable {
    /// The key of the binding being resolved.
    package let key: BindingKey

    /// The identity of the container or scope resolving the binding.
    package let context: ObjectIdentifier

    /// The source location where the binding was registered, when available.
    package let source: SkeinSourceLocation?
}
