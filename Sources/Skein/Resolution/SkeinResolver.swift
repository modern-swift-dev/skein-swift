/// Resolves registered dependencies from a Skein container.
///
/// Resolvers are sendable. Choose the main-actor, nonisolated, or asynchronous API that
/// matches the isolation of the requested binding.
public protocol SkeinResolver: AnyObject, Sendable {
    /// Resolves a service on the main actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    @MainActor func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service

    /// Resolves a sendable service without actor isolation.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service

    /// Resolves a sendable service that may require an actor-isolated provider.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service
}

/// Convenience overloads for resolving inferred or unqualified service types.
public extension SkeinResolver {
    /// Resolves an unqualified service on the main actor.
    ///
    /// - Parameter type: The service type to resolve.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    @MainActor func get<Service>(_ type: Service.Type) throws -> Service {
        try get(type, qualifier: nil)
    }

    /// Resolves an inferred service type on the main actor.
    ///
    /// - Parameter qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    @MainActor func get<Service>(qualifier: (any SkeinQualifier)? = nil) throws -> Service {
        try get(Service.self, qualifier: qualifier)
    }

    /// Resolves an unqualified sendable service without actor isolation.
    ///
    /// - Parameter type: The service type to resolve.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    func nonisolatedGet<Service: Sendable>(_ type: Service.Type) throws -> Service {
        try nonisolatedGet(type, qualifier: nil)
    }

    /// Resolves an inferred sendable service type without actor isolation.
    ///
    /// - Parameter qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    func nonisolatedGet<Service: Sendable>(qualifier: (any SkeinQualifier)? = nil) throws -> Service {
        try nonisolatedGet(Service.self, qualifier: qualifier)
    }

    /// Resolves an unqualified sendable service that may require an actor-isolated provider.
    ///
    /// - Parameter type: The service type to resolve.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    func actorGet<Service: Sendable>(_ type: Service.Type) async throws -> Service {
        try await actorGet(type, qualifier: nil)
    }

    /// Resolves an inferred sendable service type that may require an actor-isolated provider.
    ///
    /// - Parameter qualifier: The qualifier selecting a binding, or `nil` for an unqualified binding.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error or an error thrown by the binding's provider.
    func actorGet<Service: Sendable>(qualifier: (any SkeinQualifier)? = nil) async throws -> Service {
        try await actorGet(Service.self, qualifier: qualifier)
    }
}
