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
    /// Failed or cancelled startup awaits disposal of any cached services before throwing.
    ///
    /// - Parameters:
    ///   - validation: The startup validation policy.
    ///   - configure: The main-actor builder that declares the application's modules.
    /// - Throws: An error produced by configuration, structural validation, eager resolution, or cancellation.
    @MainActor public init(
        validation: ValidationPolicy,
        @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
    ) async throws {
        let container = try Container(modules: configure())
        do {
            try Task.checkCancellation()
            switch validation {
                case .declaredRoots:
                    startupValidationReport = try await container.validateDeclaredRootsAndStart()
            }
            try Task.checkCancellation()
        } catch {
            await container.close()
            throw error
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
    /// The application keeps a strong reference to the scope, and to the services it caches,
    /// until the scope is closed or the application closes. Close each scope when its work
    /// finishes; a scope that is never closed stays in memory for the application's lifetime.
    /// A scope frees its kind and ID as soon as it begins closing, so a replacement can be
    /// created while the previous scope is still disposing.
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

    /// Creates a scope instance seeded with a Sendable service.
    ///
    /// The seed is keyed by `serviceType` and `qualifier`, so pass the type of the
    /// scoped binding that should receive it. For a protocol-typed binding, pass the
    /// existential type, for example `as: (any Session).self`. Register a matching
    /// scoped binding in this scope kind before creating the scope.
    ///
    /// The seeded value is cached without calling that binding's provider, and the
    /// binding's disposer runs when the scope closes.
    ///
    /// The application keeps a strong reference to the scope, and to the services it caches,
    /// until the scope is closed or the application closes. Close each scope when its work
    /// finishes; a scope that is never closed stays in memory for the application's lifetime.
    /// A scope frees its kind and ID as soon as it begins closing, so a replacement can be
    /// created while the previous scope is still disposing.
    ///
    /// ```swift
    /// let session: any Session = LiveSession()
    /// let scope = try application.createScope(
    ///     SessionScope.self, id: 1, seeding: session, as: (any Session).self
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - type: The scope kind to create.
    ///   - id: A stable identity for the scope instance.
    ///   - service: The initial service value stored in the scope.
    ///   - serviceType: The service type of the scoped binding that receives the seed.
    ///   - qualifier: The qualifier of the scoped binding that receives the seed, or `nil`
    ///     for an unqualified binding.
    /// - Returns: The newly created scope instance.
    /// - Throws: ``SkeinError/applicationClosed`` if the application is closing or closed,
    ///   ``SkeinError/duplicateScope(scope:id:)`` if a scope with the same kind and identity
    ///   is active, or ``SkeinError/missingBinding(type:qualifier:)`` if no scoped binding
    ///   for `serviceType` and `qualifier` is registered in this scope kind.
    public func createScope<Kind: SkeinScope, Service: Sendable>(
        _ type: Kind.Type,
        id: some Hashable & Sendable,
        seeding service: Service,
        as serviceType: Service.Type,
        qualifier: (any SkeinQualifier)? = nil
    ) throws -> SkeinScopeInstance<Kind> {
        try container.createScope(type, id: id, seeding: service, as: serviceType, qualifier: qualifier)
    }

    /// Creates a scope instance seeded with a Sendable service, keyed by its static type.
    ///
    /// The seed is keyed by the argument's static type. When `service` is an existential
    /// such as `any Session`, Swift opens it to its concrete type, so the seed misses a
    /// protocol-typed binding. Use ``createScope(_:id:seeding:as:qualifier:)`` instead.
    ///
    /// The application keeps a strong reference to the scope, and to the services it caches,
    /// until the scope is closed or the application closes. Close each scope when its work
    /// finishes; a scope that is never closed stays in memory for the application's lifetime.
    /// A scope frees its kind and ID as soon as it begins closing, so a replacement can be
    /// created while the previous scope is still disposing.
    ///
    /// - Parameters:
    ///   - type: The scope kind to create.
    ///   - id: A stable identity for the scope instance.
    ///   - service: The initial service value stored in the scope.
    /// - Returns: The newly created scope instance.
    /// - Throws: A Skein error if the application is closed, the scope identity
    ///   already exists, or the matching unqualified scoped binding is missing.
    @available(*, deprecated, message: "Use createScope(_:id:seeding:as:qualifier:) to name the seeded binding's type explicitly.")
    public func createScope<Kind: SkeinScope, Service: Sendable>(
        _ type: Kind.Type,
        id: some Hashable & Sendable,
        seeding service: Service
    ) throws -> SkeinScopeInstance<Kind> {
        try container.createScope(type, id: id, seeding: service, as: Service.self, qualifier: nil)
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
    /// Cached references are released as each instance finishes disposal.
    public func close() async {
        await container.close()
    }
}
