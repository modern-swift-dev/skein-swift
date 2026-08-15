/// Type-erased storage for a scope managed by a container.
package protocol ScopeStorage: AnyObject, Sendable {
    /// Closes the scope and disposes its completed instances in an idempotent operation.
    func close() async
}
