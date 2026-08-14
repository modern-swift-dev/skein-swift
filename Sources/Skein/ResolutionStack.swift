import Foundation

package enum ResolutionContext {
    @TaskLocal package static var entries: [ResolutionTraceEntry] = []
}

package struct ResolutionTraceEntry: @unchecked Sendable {
    package let key: BindingKey
    package let context: ObjectIdentifier
    package let source: SkeinSourceLocation?
}

/// Identifies one shared asynchronous singleton/scoped creation. Unlike the
/// ordinary resolution trace, this identity also distinguishes independently
/// started tasks resolving the same graph concurrently.
package struct AsyncCreationIdentity: Hashable, @unchecked Sendable {
    package let context: ObjectIdentifier
    package let token: UUID
    package let key: BindingKey
}

package struct AsyncWaitEdge: Hashable, @unchecked Sendable {
    package let source: AsyncCreationIdentity
    package let target: AsyncCreationIdentity
}

package enum AsyncCreationContext {
    @TaskLocal package static var current: AsyncCreationIdentity?
}
