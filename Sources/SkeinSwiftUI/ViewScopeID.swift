#if canImport(SwiftUI)
    import Foundation

    /// The identity under which a view-owned scope is registered with its application.
    ///
    /// It combines the caller's scope ID with a token unique to the owning view, so view-owned
    /// scopes never conflict with each other or with scopes created directly from the
    /// application. This lets SwiftUI build a replacement view before it releases the old one.
    /// Diagnostics show only the caller's ID.
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) struct ViewScopeID<ID: Hashable & Sendable>: Hashable, Sendable, CustomStringConvertible {
        /// The ID passed to `skeinScope(_:id:)`.
        let id: ID
        /// The token of the view that owns the scope.
        let owner: UUID

        var description: String {
            String(describing: id)
        }
    }
#endif
