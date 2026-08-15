#if os(macOS) || os(Linux)
// swiftformat:disable opaqueGenericParameters,conditionalAssignment
import Skein
import Vapor

/// Access to Skein configuration and application-lifetime resolution.
///
/// Obtain this value from `Application.skein`. Initialize it once
/// during Vapor configuration, then use its resolution methods for services that
/// do not require a request scope.
public struct SkeinVaporApplication: Sendable {
    private let application: Application

    init(application: Application) {
        self.application = application
    }

    /// Installs one Skein application and request-scope middleware on this Vapor application.
    ///
    /// Pass `nil` for `validation` to use lazy, unvalidated construction.
    /// The middleware is inserted at the beginning of Vapor's middleware chain.
    /// Application resources are disposed when Vapor invokes `asyncShutdown()`.
    ///
    /// - Parameters:
    ///   - validation: The graph validation policy, or `nil` to skip validation.
    ///   - configure: A builder that returns the modules installed in the Skein application.
    /// - Throws: ``SkeinVaporError/applicationAlreadyInitialized`` when called more
    ///   than once, or a Skein construction or validation error.
    @MainActor public func initialize(
        validation: ValidationPolicy? = .declaredRoots,
        @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
    ) async throws {
        guard application.storage[SkeinApplicationStorageKey.self] == nil else {
            throw SkeinVaporError.applicationAlreadyInitialized
        }

        let modules = configure()
        let requestModule = module {
            nonisolatedScoped(Request.self, scope: VaporRequestScope.self) { _ in
                throw SkeinVaporError.requestScopeUnavailable
            }
        }
        let skeinApplication: SkeinApplication
        if let validation {
            skeinApplication = try await SkeinApplication(validation: validation) {
                modules
                requestModule
            }
        } else {
            skeinApplication = try SkeinApplication {
                modules
                requestModule
            }
        }

        application.storage[SkeinApplicationStorageKey.self] = skeinApplication
        application.lifecycle.use(SkeinVaporLifecycle(application: skeinApplication))
        application.middleware.use(
            SkeinVaporRequestScopeMiddleware(application: skeinApplication),
            at: .beginning
        )
    }

    /// Resolves a Sendable application-lifetime service.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/applicationNotInitialized`` when Skein has not
    ///   been initialized, or a Skein resolution error.
    public func get<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try configuredApplication().nonisolatedGet(type, qualifier: qualifier)
    }

    /// Resolves a Sendable application-lifetime service.
    ///
    /// - Parameter qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The inferred service type.
    /// - Throws: ``SkeinVaporError/applicationNotInitialized`` when Skein has not
    ///   been initialized, or a Skein resolution error.
    public func get<Service: Sendable>(
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try get(Service.self, qualifier: qualifier)
    }

    /// Resolves a Sendable assisted application-lifetime service.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The assisted arguments passed to the registered provider.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/applicationNotInitialized`` when Skein has not
    ///   been initialized, or a Skein resolution error.
    public func get<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try configuredApplication().nonisolatedGet(
            type,
            arguments: arguments,
            qualifier: qualifier
        )
    }

    /// Resolves a Sendable application-lifetime service on its registered global actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/applicationNotInitialized`` when Skein has not
    ///   been initialized, or a Skein resolution error.
    public func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await configuredApplication().actorGet(type, qualifier: qualifier)
    }

    /// Resolves a Sendable application-lifetime service on its registered global actor.
    ///
    /// - Parameter qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The inferred service type.
    /// - Throws: ``SkeinVaporError/applicationNotInitialized`` when Skein has not
    ///   been initialized, or a Skein resolution error.
    public func actorGet<Service: Sendable>(
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await actorGet(Service.self, qualifier: qualifier)
    }

    /// Resolves a Sendable assisted application-lifetime service on its registered global actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The assisted arguments passed to the registered provider.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/applicationNotInitialized`` when Skein has not
    ///   been initialized, or a Skein resolution error.
    public func actorGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await configuredApplication().actorGet(
            type,
            arguments: arguments,
            qualifier: qualifier
        )
    }

    private func configuredApplication() throws -> SkeinApplication {
        guard let skeinApplication = application.storage[SkeinApplicationStorageKey.self] else {
            throw SkeinVaporError.applicationNotInitialized
        }
        return skeinApplication
    }
}
#endif
