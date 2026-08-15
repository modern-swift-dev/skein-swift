/// An independently owned Skein dependency container.
public final class SkeinApplication: Resolver, @unchecked Sendable {
    /// The container that owns this application's registrations and cached values.
    package let container: Container

    /// The structural report produced by validated startup, or `nil` when the
    /// application was constructed without validation.
    public let startupValidationReport: GraphValidationReport?

    /// Creates an application without startup graph validation.
    ///
    /// - Parameter configure: The main-actor builder that declares the application's modules.
    /// - Throws: A configuration error when the declared modules are invalid.
    @MainActor public init(@SkeinApplicationBuilder _ configure: @MainActor () -> [Module]) throws {
        container = try Container(modules: configure())
        startupValidationReport = nil
    }

    /// Creates an application and performs the requested startup validation.
    ///
    /// - Parameters:
    ///   - validation: The startup validation policy.
    ///   - configure: The main-actor builder that declares the application's modules.
    /// - Throws: An error produced by configuration, structural validation, or eager resolution.
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

    /// Resolves a main-actor service owned by this application.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting the binding, or `nil`.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error when the binding cannot produce the requested service.
    @MainActor public func get<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.get(type, qualifier: qualifier)
    }

    /// Resolves an assisted main-actor service owned by this application.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The assisted arguments passed to the provider.
    ///   - qualifier: The qualifier selecting the binding, or `nil`.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error when the binding cannot produce the requested service.
    @MainActor public func get<Service>(
        _ type: Service.Type = Service.self,
        arguments: some Any,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.assistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    /// Resolves a sendable nonisolated service owned by this application.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting the binding, or `nil`.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error when the binding cannot produce the requested service.
    public func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) throws -> Service {
        try container.nonisolatedGet(type, qualifier: qualifier)
    }

    /// Resolves an assisted sendable nonisolated service owned by this application.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The assisted arguments passed to the provider.
    ///   - qualifier: The qualifier selecting the binding, or `nil`.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error when the binding cannot produce the requested service.
    public func nonisolatedGet<Service: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: some Sendable,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> Service {
        try container.nonisolatedAssistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    /// Resolves a service on its registered custom actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - qualifier: The qualifier selecting the binding, or `nil`.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error when the binding cannot produce the requested service.
    public func actorGet<Service: Sendable>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)?
    ) async throws -> Service {
        try await container.actorGet(type, qualifier: qualifier)
    }

    /// Resolves an assisted service on its registered custom actor.
    ///
    /// - Parameters:
    ///   - type: The service type to resolve.
    ///   - arguments: The assisted arguments passed to the provider.
    ///   - qualifier: The qualifier selecting the binding, or `nil`.
    /// - Returns: The resolved service.
    /// - Throws: A resolution error when the binding cannot produce the requested service.
    public func actorGet<Service: Sendable>(
        _ type: Service.Type = Service.self,
        arguments: some Sendable,
        qualifier: (any SkeinQualifier)? = nil
    ) async throws -> Service {
        try await container.actorAssistedGet(type, arguments: arguments, qualifier: qualifier)
    }

    /// Creates a main-actor scope instance owned by this application.
    ///
    /// - Parameters:
    ///   - type: The scope kind to create.
    ///   - id: A stable identity for the scope instance.
    /// - Returns: The newly created scope instance.
    /// - Throws: A configuration error when the scope cannot be created.
    @MainActor public func createScope<Kind: SkeinScope>(
        _ type: Kind.Type,
        id: some Hashable & Sendable
    ) throws -> SkeinScopeInstance<Kind> {
        try container.createScope(type, id: id)
    }

    /// Creates a scope instance seeded with a sendable service.
    ///
    /// - Parameters:
    ///   - type: The scope kind to create.
    ///   - id: A stable identity for the scope instance.
    ///   - service: The initial service value stored in the scope.
    /// - Returns: The newly created scope instance.
    /// - Throws: A configuration error when the scope cannot be created.
    package func createScope<Kind: SkeinScope>(
        _ type: Kind.Type,
        id: some Hashable & Sendable,
        seeding service: some Sendable
    ) throws -> SkeinScopeInstance<Kind> {
        try container.createScope(type, id: id, seeding: service)
    }

    /// Structurally validates every binding marked as an application root.
    ///
    /// - Returns: A report describing opaque bindings reached during validation.
    /// - Throws: ``GraphValidationError`` when the declared root graph is invalid.
    public func validateGraph() throws -> GraphValidationReport {
        try container.validateGraph()
    }

    /// Closes the application and awaits disposal of its cached services.
    ///
    /// Calling this method more than once has no additional effect.
    public func close() async {
        await container.close()
    }
}
