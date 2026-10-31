#if canImport(SwiftUI)
    import Foundation
    import Skein
    import SwiftUI

    /// Gives a view's subtree a scope that lives as long as the view's SwiftUI identity.
    @MainActor
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) struct SkeinScopeModifier<Kind: SkeinScope>: ViewModifier {
        @Environment(\.skeinApplication) private var application
        @Environment(\.skeinScopes) private var scopes
        @State private var owner = ScopeOwner<Kind>()

        let id: AnyHashable
        let create: @MainActor (SkeinApplication, UUID) throws -> SkeinScopeInstance<Kind>

        func body(content: Content) -> some View {
            let entry = owner.entry(application: application, id: id, create: create)
            return content.environment(\.skeinScopes, scopes.setting(entry, for: Kind.self))
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) public extension View {
        /// Gives this view and its descendants a scope owned by this view.
        ///
        /// The scope is created from the environment's application on the first update that finds
        /// one, and descendants resolve from it with `.resolving(in:)` on ``SkeinStateObject`` or
        /// ``SkeinState``. Nested modifiers of the same kind follow nearest-value-wins behavior;
        /// scopes of other kinds are unaffected.
        ///
        /// The scope stays open for the lifetime of this view's SwiftUI identity, across
        /// re-renders, tab switches and navigation pushes. When the identity ends, the scope begins
        /// closing and its disposers run asynchronously.
        ///
        /// Each view owns its own scope: view-owned scopes never conflict with each other or with
        /// scopes created directly from the application, even when they share a kind and `id`.
        /// This lets SwiftUI build a replacement view before releasing the old one. The `id`
        /// identifies the scope in diagnostics.
        ///
        /// The first `id` is kept for the view's identity: if it later changes, the original scope
        /// is kept and a DEBUG warning is printed. Give the view a new identity with `.id(...)` to
        /// replace the scope. If creating the scope fails, descendants receive
        /// ``SkeinSwiftUIError/scopeCreationFailed(scope:underlying:)``.
        ///
        /// - Parameters:
        ///   - kind: The scope kind to create.
        ///   - id: A stable identity for the scope instance.
        /// - Returns: A view whose descendants can resolve from the scope.
        func skeinScope<Kind: SkeinScope>(_ kind: Kind.Type, id: some Hashable & Sendable) -> some View {
            modifier(SkeinScopeModifier<Kind>(id: AnyHashable(id), create: { application, owner in
                try application.createScope(kind, id: ViewScopeID(id: id, owner: owner))
            }))
        }

        /// Gives this view and its descendants a scope owned by this view, seeded with a service.
        ///
        /// The seed is placed in the scope when it is created, exactly as with
        /// `SkeinApplication.createScope(_:id:seeding:as:qualifier:)`. It is captured once: later
        /// changes to `service` are ignored for the view's identity. See ``skeinScope(_:id:)`` for
        /// the scope's lifetime.
        ///
        /// - Parameters:
        ///   - kind: The scope kind to create.
        ///   - id: A stable identity for the scope instance.
        ///   - service: The initial service value stored in the scope.
        ///   - serviceType: The service type of the scoped binding that receives the seed.
        ///   - qualifier: The qualifier of the scoped binding that receives the seed, or `nil`.
        /// - Returns: A view whose descendants can resolve from the scope.
        func skeinScope<Kind: SkeinScope, Service: Sendable>(
            _ kind: Kind.Type,
            id: some Hashable & Sendable,
            seeding service: Service,
            as serviceType: Service.Type,
            qualifier: (any SkeinQualifier)? = nil
        ) -> some View {
            modifier(SkeinScopeModifier<Kind>(id: AnyHashable(id), create: { application, owner in
                try application.createScope(
                    kind,
                    id: ViewScopeID(id: id, owner: owner),
                    seeding: service,
                    as: serviceType,
                    qualifier: qualifier
                )
            }))
        }
    }
#endif
