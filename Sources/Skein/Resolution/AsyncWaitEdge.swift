/// A directed wait between two asynchronous dependency creations.
package struct AsyncWaitEdge: Hashable, @unchecked Sendable {
    /// The creation waiting for another creation to complete.
    package let source: AsyncCreationIdentity

    /// The creation whose completion is being awaited.
    package let target: AsyncCreationIdentity
}
