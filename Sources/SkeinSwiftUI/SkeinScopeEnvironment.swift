#if canImport(SwiftUI)
    import Skein
    import SwiftUI

    /// The view-owned scopes visible to a view, keyed by scope kind.
    ///
    /// Each `.skeinScope(_:id:)` modifier adds or replaces the entry for its kind, so the nearest
    /// scope of a given kind wins and scopes of other kinds are unaffected.
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) struct SkeinScopeEnvironment: Sendable {
        /// The state of a view-owned scope.
        enum Entry: Sendable {
            /// The owning view has no application yet, so the scope has not been created.
            case pending
            /// The scope exists and accepts resolution.
            case available(any AnyObject & Sendable)
            /// Creating the scope failed.
            case failed(SkeinError)
        }

        private var entries: [ObjectIdentifier: Entry] = [:]

        /// Returns a copy in which `entry` is the scope for `kind`.
        ///
        /// - Parameters:
        ///   - entry: The state of the scope.
        ///   - kind: The scope kind the entry belongs to.
        /// - Returns: The updated environment.
        func setting(_ entry: Entry, for kind: (some SkeinScope).Type) -> Self {
            var copy = self
            copy.entries[ObjectIdentifier(kind)] = entry
            return copy
        }

        /// Returns the nearest available scope of `kind`.
        ///
        /// - Parameter kind: The scope kind to look up.
        /// - Returns: The view-owned scope.
        /// - Throws: ``SkeinSwiftUIError/missingScope(scope:)`` when no scope of that kind is above
        ///   the view, ``SkeinSwiftUIError/missingApplication`` when the scope is waiting for an
        ///   application, or ``SkeinSwiftUIError/scopeCreationFailed(scope:underlying:)``.
        func scope<Kind: SkeinScope>(_ kind: Kind.Type) throws -> SkeinScopeInstance<Kind> {
            switch entries[ObjectIdentifier(kind)] {
                case let .available(scope as SkeinScopeInstance<Kind>):
                    return scope
                case .pending:
                    throw SkeinSwiftUIError.missingApplication
                case let .failed(error):
                    throw SkeinSwiftUIError.scopeCreationFailed(scope: String(reflecting: kind), underlying: error)
                case .available,
                     nil:
                    throw SkeinSwiftUIError.missingScope(scope: String(reflecting: kind))
            }
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct SkeinScopeEnvironmentKey: EnvironmentKey {
        static let defaultValue = SkeinScopeEnvironment()
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) extension EnvironmentValues {
        /// The view-owned scopes supplied by surrounding `.skeinScope(_:id:)` modifiers.
        var skeinScopes: SkeinScopeEnvironment {
            get { self[SkeinScopeEnvironmentKey.self] }
            set { self[SkeinScopeEnvironmentKey.self] = newValue }
        }
    }
#endif
