import Foundation

/// Identifies one shared asynchronous singleton/scoped creation. Unlike the
/// ordinary resolution trace, this identity also distinguishes independently
/// started tasks resolving the same graph concurrently.
package struct AsyncCreationIdentity: Hashable, @unchecked Sendable {
    /// The identity of the container or scope performing the creation.
    package let context: ObjectIdentifier

    /// A token distinguishing this creation from concurrent creations of the same binding.
    package let token: UUID

    /// The key of the binding being created.
    package let key: BindingKey
}
