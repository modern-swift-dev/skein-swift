/// Resolves registered dependencies from a Skein container.
public protocol SkeinResolver: AnyObject, Sendable {
    @MainActor func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service

    func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service

    func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service
}

public typealias Resolver = SkeinResolver

public extension SkeinResolver {
    @MainActor func get<Service>(_ type: Service.Type) throws -> Service {
        try get(type, qualifier: nil)
    }

    @MainActor func get<Service>(qualifier: (any SkeinQualifier)? = nil) throws -> Service {
        try get(Service.self, qualifier: qualifier)
    }

    func nonisolatedGet<Service: Sendable>(_ type: Service.Type) throws -> Service {
        try nonisolatedGet(type, qualifier: nil)
    }

    func nonisolatedGet<Service: Sendable>(qualifier: (any SkeinQualifier)? = nil) throws -> Service {
        try nonisolatedGet(Service.self, qualifier: qualifier)
    }

    func actorGet<Service: Sendable>(_ type: Service.Type) async throws -> Service {
        try await actorGet(type, qualifier: nil)
    }

    func actorGet<Service: Sendable>(qualifier: (any SkeinQualifier)? = nil) async throws -> Service {
        try await actorGet(Service.self, qualifier: qualifier)
    }
}
