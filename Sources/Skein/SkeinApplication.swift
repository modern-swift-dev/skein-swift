/// An independently owned Skein dependency container.
public final class SkeinApplication: Resolver, @unchecked Sendable {
    package let container: Container

    public init(@SkeinApplicationBuilder _ configure: () -> [Module]) throws {
        container = try Container(modules: configure())
    }

    @MainActor public init(
        validating manifest: [DependencyProbe],
        @SkeinApplicationBuilder _ configure: () -> [Module]
    ) throws {
        let container = try Container(modules: configure())
        for probe in manifest {
            try probe.validate(in: container)
        }
        self.container = container
    }

    public func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.get(type, qualifier: qualifier)
    }

    public func get<Service>(
        _ type: Service.Type = Service.self,
        arguments: some Any,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.assistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    @MainActor public func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.mainActorGet(type, qualifier: qualifier)
    }

    @MainActor public func mainActorGet<Service>(
        _ type: Service.Type = Service.self,
        arguments: some Any,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.mainActorAssistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    public func createScope<Kind: SkeinScope>(
        _ type: Kind.Type,
        id: some Hashable & Sendable
    ) throws -> SkeinScopeInstance<Kind> {
        try container.createScope(type, id: id)
    }

    /// Structurally validates declared roots without executing providers.
    public func validateGraph() throws -> GraphValidationReport {
        try container.validateGraph()
    }

    @available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) public func close() async {
        await container.close()
    }
}
