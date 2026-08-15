/// Controls application startup validation.
public enum ValidationPolicy: Sendable {
    case declaredRoots
}

/// An independently owned Skein dependency container.
public final class SkeinApplication: Resolver, @unchecked Sendable {
    package let container: Container

    /// The structural report produced by validated startup, or `nil` when the
    /// application was constructed without validation.
    public let startupValidationReport: GraphValidationReport?

    @MainActor public init(@SkeinApplicationBuilder _ configure: @MainActor () -> [Module]) throws {
        container = try Container(modules: configure())
        startupValidationReport = nil
    }

    @MainActor public init(
        validation: ValidationPolicy,
        @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
    ) async throws {
        let container = try Container(modules: configure())
        switch validation {
            case .declaredRoots:
                startupValidationReport = try await container.validateDeclaredRootsAndStart()
        }
        self.container = container
    }

    @MainActor public func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.get(type, qualifier: qualifier)
    }

    @MainActor public func get<Service, Arguments>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.assistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    public func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.nonisolatedGet(type, qualifier: qualifier)
    }

    public func nonisolatedGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.nonisolatedAssistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    public func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service {
        try await container.actorGet(type, qualifier: qualifier)
    }

    public func actorGet<Service: Sendable, Arguments: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await container.actorAssistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    @MainActor public func createScope<Kind: SkeinScope>(
        _ type: Kind.Type,
        id: some Hashable & Sendable
    ) throws -> SkeinScopeInstance<Kind> {
        try container.createScope(type, id: id)
    }

    package func createScope<Kind: SkeinScope, Service: Sendable>(
        _ type: Kind.Type,
        id: some Hashable & Sendable,
        seeding service: Service
    ) throws -> SkeinScopeInstance<Kind> {
        try container.createScope(type, id: id, seeding: service)
    }

    /// Structurally validates every binding marked as an application root.
    public func validateGraph() throws -> GraphValidationReport {
        try container.validateGraph()
    }

    public func close() async {
        await container.close()
    }
}
