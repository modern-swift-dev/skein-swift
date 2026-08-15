/// Registers a main-actor singleton constructed from resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional callback run when the cached service is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The main-actor constructor whose parameter pack declares dependencies.
/// - Returns: A singleton binding with structural dependency metadata.
@MainActor public func single<Service, each Dependency>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @MainActor (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    return single(type, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.get((each Dependency).self))
    }.withDependencies(edges)
}

/// Registers a main-actor factory constructed from resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The main-actor constructor whose parameter pack declares dependencies.
/// - Returns: A factory binding with structural dependency metadata.
@MainActor public func factory<Service, each Dependency>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @MainActor (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    return factory(type, qualifier: qualifier, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.get((each Dependency).self))
    }.withDependencies(edges)
}

/// Registers an assisted main-actor factory constructed from resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - arguments: The assisted argument type required for resolution.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The main-actor constructor receiving assisted arguments followed by dependencies.
/// - Returns: An assisted factory binding with structural dependency metadata.
@MainActor public func factory<Service, Arguments, each Dependency>(
    _ type: Service.Type, arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @MainActor (Arguments, repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    return factory(type, arguments: arguments, qualifier: qualifier, fileID: fileID, line: line) { resolver, arguments in
        try constructor(arguments, repeat resolver.get((each Dependency).self))
    }.withDependencies(edges)
}

/// Registers a sendable nonisolated singleton constructed from resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional sendable callback run when the cached service is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The sendable constructor whose parameter pack declares dependencies.
/// - Returns: A singleton binding with structural dependency metadata.
public func nonisolatedSingle<Service: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @Sendable (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    return nonisolatedSingle(type, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.nonisolatedGet((each Dependency).self))
    }.withDependencies(edges)
}

/// Registers a sendable nonisolated factory constructed from resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The sendable constructor whose parameter pack declares dependencies.
/// - Returns: A factory binding with structural dependency metadata.
public func nonisolatedFactory<Service: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @Sendable (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    return nonisolatedFactory(type, qualifier: qualifier, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.nonisolatedGet((each Dependency).self))
    }.withDependencies(edges)
}

/// Registers an assisted sendable nonisolated factory constructed from dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - arguments: The assisted argument type required for resolution.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The sendable constructor receiving assisted arguments followed by dependencies.
/// - Returns: An assisted factory binding with structural dependency metadata.
public func nonisolatedFactory<Service: Sendable, Arguments: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @Sendable (Arguments, repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    return nonisolatedFactory(type, arguments: arguments, qualifier: qualifier, fileID: fileID, line: line) { resolver, arguments in
        try constructor(arguments, repeat resolver.nonisolatedGet((each Dependency).self))
    }.withDependencies(edges)
}

/// Swift 6.0 misdiagnoses pack arguments passed directly to @isolated(any) functions.
/// Async function conversion preserves runtime isolation while avoiding that static crossing.
/// Registers a custom-actor singleton constructed from asynchronously resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - isolatedTo: The global actor on which the constructor and disposer execute.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - onClose: An optional actor-isolated callback run when the cached service is disposed.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The actor-isolated constructor whose parameter pack declares dependencies.
/// - Returns: A singleton binding with structural dependency metadata.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorSingle<Service: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, isolatedTo: (some GlobalActor).Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@isolated(any) @Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @isolated(any) @Sendable (repeat each Dependency) async throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    let actualActorID = constructor.isolation.map(ObjectIdentifier.init)
    let callable: @Sendable (repeat each Dependency) async throws -> Service = constructor
    return actorSingle(
        type,
        isolatedTo: isolatedTo,
        qualifier: qualifier,
        onClose: onClose,
        fileID: fileID,
        line: line
    ) { resolver in
        try await callable(repeat resolver.actorGet((each Dependency).self))
    }.withDependencies(edges).withActualActorID(actualActorID)
}

/// Registers a custom-actor factory constructed from asynchronously resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - isolatedTo: The global actor on which the constructor executes.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The actor-isolated constructor whose parameter pack declares dependencies.
/// - Returns: A factory binding with structural dependency metadata.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorFactory<Service: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, isolatedTo: (some GlobalActor).Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @isolated(any) @Sendable (repeat each Dependency) async throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    let actualActorID = constructor.isolation.map(ObjectIdentifier.init)
    let callable: @Sendable (repeat each Dependency) async throws -> Service = constructor
    return actorFactory(type, isolatedTo: isolatedTo, qualifier: qualifier, fileID: fileID, line: line) { resolver in
        try await callable(repeat resolver.actorGet((each Dependency).self))
    }.withDependencies(edges).withActualActorID(actualActorID)
}

/// Registers an assisted custom-actor factory constructed from resolved dependencies.
///
/// - Parameters:
///   - type: The service type to register.
///   - arguments: The assisted argument type required for resolution.
///   - isolatedTo: The global actor on which the constructor executes.
///   - qualifier: The qualifier distinguishing this binding, or `nil`.
///   - fileID: The source file containing the registration.
///   - line: The source line containing the registration.
///   - constructor: The actor-isolated constructor receiving arguments followed by dependencies.
/// - Returns: An assisted factory binding with structural dependency metadata.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *) public func actorFactory<Service: Sendable, Arguments: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, arguments: Arguments.Type, isolatedTo: (some GlobalActor).Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @isolated(any) @Sendable (Arguments, repeat each Dependency) async throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self {
        edges.append(.init(dependency))
    }
    let actualActorID = constructor.isolation.map(ObjectIdentifier.init)
    let callable: @Sendable (Arguments, repeat each Dependency) async throws -> Service = constructor
    return actorFactory(
        type,
        arguments: arguments,
        isolatedTo: isolatedTo,
        qualifier: qualifier,
        fileID: fileID,
        line: line
    ) { resolver, arguments in
        try await callable(arguments, repeat resolver.actorGet((each Dependency).self))
    }.withDependencies(edges).withActualActorID(actualActorID)
}

private extension Binding {
    func withDependencies(_ dependencies: [BindingDependency]) -> Binding {
        Binding(
            key: key,
            lifetime: lifetime,
            isolation: isolation,
            provider: provider,
            disposer: disposer,
            source: source,
            dependencies: dependencies,
            rootPolicy: rootPolicy,
            rootSource: rootSource
        )
    }

    func withActualActorID(_ actualActorID: ObjectIdentifier?) -> Binding {
        let replacement: BindingProvider = switch provider {
            case let .customActor(storage):
                .customActor(.init(
                    expectedActorID: storage.expectedActorID,
                    actualActorID: actualActorID,
                    actorName: storage.actorName,
                    invoke: storage.invoke
                ))
            case let .customActorAssisted(storage):
                .customActorAssisted(.init(
                    expectedActorID: storage.expectedActorID,
                    actualActorID: actualActorID,
                    actorName: storage.actorName,
                    invoke: storage.invoke
                ))
            default: provider
        }
        return Binding(
            key: key,
            lifetime: lifetime,
            isolation: isolation,
            provider: replacement,
            disposer: disposer,
            source: source,
            dependencies: dependencies,
            rootPolicy: rootPolicy,
            rootSource: rootSource
        )
    }
}
