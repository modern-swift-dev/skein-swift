/// Resolves registered dependencies from a Koin container.
public protocol Resolver: AnyObject {
    func get<Service>(_ type: Service.Type, qualifier: (any KoinQualifier)?) throws -> Service
}

public extension Resolver {
    func get<Service>(_ type: Service.Type) throws -> Service {
        try get(type, qualifier: nil)
    }

    func get<Service>(qualifier: (any KoinQualifier)? = nil) throws -> Service {
        try get(Service.self, qualifier: qualifier)
    }
}
