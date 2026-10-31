#if canImport(SwiftUI)
    import Skein

    /// What a resolving wrapper finds in its SwiftUI environment: the application and view-owned scopes.
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) struct WrapperEnvironment {
        /// The nearest application, if any.
        let application: SkeinApplication?
        /// The view-owned scopes above the wrapper.
        let scopes: SkeinScopeEnvironment

        /// Returns the application, or throws when none is in the environment.
        ///
        /// - Returns: The nearest application.
        /// - Throws: ``SkeinSwiftUIError/missingApplication``.
        func requireApplication() throws -> SkeinApplication {
            guard let application else {
                throw SkeinSwiftUIError.missingApplication
            }
            return application
        }
    }
#endif
