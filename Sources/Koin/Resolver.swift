/// Resolves registered dependencies from a Koin container.
public protocol Resolver: AnyObject {
    func get<Service>(_ type: Service.Type, qualifier: (any KoinQualifier)?) throws -> Service

    /// Resolves an ordinary or main-actor binding while isolated to the main
    /// actor. Registered service types do not need to conform to `Sendable`.
    @MainActor
    func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?
    ) throws -> Service
}

public extension Resolver {
    func get<Service>(_ type: Service.Type) throws -> Service {
        try get(type, qualifier: nil)
    }

    func get<Service>(qualifier: (any KoinQualifier)? = nil) throws -> Service {
        try get(Service.self, qualifier: qualifier)
    }

    @MainActor
    func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?
    ) throws -> Service {
        try get(type, qualifier: qualifier)
    }

    @MainActor
    func mainActorGet<Service>(_ type: Service.Type) throws -> Service {
        try mainActorGet(type, qualifier: nil)
    }

    @MainActor
    func mainActorGet<Service>(qualifier: (any KoinQualifier)? = nil) throws -> Service {
        try mainActorGet(Service.self, qualifier: qualifier)
    }
}
