#if os(macOS) || os(Linux)
// swiftformat:disable opaqueGenericParameters
import Skein
import Vapor

/// Access to the active request scope.
///
/// Obtain this value from `Request.skein` inside middleware or a
/// route handler. The scope closes before deferred streaming-body callbacks run.
public struct SkeinVaporRequest: Sendable {
    private let request: Request

    init(request: Request) {
        self.request = request
    }

    /// Resolves a Sendable service from the current request scope.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/requestScopeUnavailable`` outside the active
    ///   middleware chain, or a Skein resolution error.
    public func get<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try scope().nonisolatedGet(type, qualifier: qualifier)
    }

    /// Resolves a Sendable service from the current request scope.
    ///
    /// - Parameter qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The inferred service type.
    /// - Throws: ``SkeinVaporError/requestScopeUnavailable`` outside the active
    ///   middleware chain, or a Skein resolution error.
    public func get<Service: Sendable>(
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try get(Service.self, qualifier: qualifier)
    }

    /// Resolves a Sendable assisted service from the current request scope.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The assisted arguments passed to the registered provider.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/requestScopeUnavailable`` outside the active
    ///   middleware chain, or a Skein resolution error.
    public func get<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try scope().nonisolatedGet(type, arguments: arguments, qualifier: qualifier)
    }

    /// Resolves a Sendable service from the current request scope on its registered global actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/requestScopeUnavailable`` outside the active
    ///   middleware chain, or a Skein resolution error.
    public func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await scope().actorGet(type, qualifier: qualifier)
    }

    /// Resolves a Sendable service from the current request scope on its registered global actor.
    ///
    /// - Parameter qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The inferred service type.
    /// - Throws: ``SkeinVaporError/requestScopeUnavailable`` outside the active
    ///   middleware chain, or a Skein resolution error.
    public func actorGet<Service: Sendable>(
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await actorGet(Service.self, qualifier: qualifier)
    }

    /// Resolves a Sendable assisted service from the current request scope on its registered global actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The assisted arguments passed to the registered provider.
    ///   - qualifier: An optional qualifier selecting a specific binding.
    /// - Returns: The resolved service.
    /// - Throws: ``SkeinVaporError/requestScopeUnavailable`` outside the active
    ///   middleware chain, or a Skein resolution error.
    public func actorGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await scope().actorGet(type, arguments: arguments, qualifier: qualifier)
    }

    private func scope() throws -> SkeinScopeInstance<VaporRequestScope> {
        guard let scope = request.storage[SkeinRequestScopeStorageKey.self] else {
            throw SkeinVaporError.requestScopeUnavailable
        }
        return scope
    }
}
#endif
