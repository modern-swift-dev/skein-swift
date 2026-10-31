#if canImport(SwiftUI)
    import Foundation
    import Skein

    /// Creates and owns the scope of a `.skeinScope(_:id:)` modifier for its view's SwiftUI identity.
    ///
    /// The scope is created lazily, on the first update that finds an application. A creation
    /// failure is kept, like a provider failure. When the owning view's identity ends, this object
    /// is deallocated and the scope begins closing.
    ///
    /// The class is not actor-isolated so SwiftUI can create it in `@State` storage; its state is
    /// only read and written by ``entry(application:id:create:)``, which runs on the main actor.
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) final class ScopeOwner<Kind: SkeinScope> {
        /// Distinguishes this owner's scope from other view-owned scopes with the same kind and ID.
        let token = UUID()
        private var scope: SkeinScopeInstance<Kind>?
        private var failure: SkeinError?
        #if DEBUG
            private var createdID: AnyHashable?
        #endif

        /// Returns the scope's state, creating the scope when an application is available.
        ///
        /// - Parameters:
        ///   - application: The application in the owning view's environment, if any.
        ///   - id: The scope ID currently passed to the modifier.
        ///   - create: Creates the scope from an application and this owner's ``token``.
        /// - Returns: The environment entry describing the scope.
        @MainActor func entry(
            application: SkeinApplication?,
            id: AnyHashable,
            create: (SkeinApplication, UUID) throws -> SkeinScopeInstance<Kind>
        ) -> SkeinScopeEnvironment.Entry {
            if let scope {
                #if DEBUG
                    if createdID != id {
                        debugPrint("skeinScope(\(String(reflecting: Kind.self)), id:) kept its original scope because its ID changed. Use .id(...) to replace it.")
                    }
                #endif
                return .available(scope)
            }
            if let failure {
                return .failed(failure)
            }
            guard let application else {
                return .pending
            }
            do {
                let created = try create(application, token)
                scope = created
                #if DEBUG
                    createdID = id
                #endif
                return .available(created)
            } catch let error as SkeinError {
                failure = error
                return .failed(error)
            } catch {
                preconditionFailure("SkeinApplication.createScope reports failures as SkeinError, but threw \(error)")
            }
        }

        deinit {
            // Erased so the closing task does not capture the generic scope kind.
            if let scope = scope as (any ScopeStorage)? {
                Task { await scope.close() }
            }
        }
    }
#endif
