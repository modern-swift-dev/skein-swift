/// Resolves registered dependencies from a Skein container.
public protocol SkeinResolver: AnyObject {
    func get<Service>(_ type: Service.Type, qualifier: (any SkeinQualifier)?) throws -> Service

    /// Resolves an ordinary or main-actor binding while isolated to the main
    /// actor. Registered service types do not need to conform to `Sendable`.
    @MainActor func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service
}

public typealias Resolver = SkeinResolver

public extension SkeinResolver {
    func get<Service>(_ type: Service.Type) throws -> Service {
        try get(type, qualifier: nil)
    }

    func get<Service>(qualifier: (any SkeinQualifier)? = nil) throws -> Service {
        try get(Service.self, qualifier: qualifier)
    }

    @MainActor func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try get(type, qualifier: qualifier)
    }

    @MainActor func mainActorGet<Service>(_ type: Service.Type) throws -> Service {
        try mainActorGet(type, qualifier: nil)
    }

    @MainActor func mainActorGet<Service>(qualifier: (any SkeinQualifier)? = nil) throws -> Service {
        try mainActorGet(Service.self, qualifier: qualifier)
    }
}
