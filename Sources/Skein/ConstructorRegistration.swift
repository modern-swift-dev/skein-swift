// Constructor overloads use parameter packs so dependency metadata is complete
// at every arity. The assisted argument, when present, is always first.

@MainActor public func single<Service, each Dependency>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @MainActor (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    return single(type, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.get((each Dependency).self))
    }.withDependencies(edges)
}

@MainActor public func factory<Service, each Dependency>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @MainActor (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    return factory(type, qualifier: qualifier, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.get((each Dependency).self))
    }.withDependencies(edges)
}

@MainActor public func factory<Service, Arguments, each Dependency>(
    _ type: Service.Type, arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @MainActor (Arguments, repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    return factory(type, arguments: arguments, qualifier: qualifier, fileID: fileID, line: line) { resolver, arguments in
        try constructor(arguments, repeat resolver.get((each Dependency).self))
    }.withDependencies(edges)
}

public func nonisolatedSingle<Service: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    onClose: (@Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @Sendable (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    return nonisolatedSingle(type, qualifier: qualifier, onClose: onClose, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.nonisolatedGet((each Dependency).self))
    }.withDependencies(edges)
}

public func nonisolatedFactory<Service: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @Sendable (repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    return nonisolatedFactory(type, qualifier: qualifier, fileID: fileID, line: line) { resolver in
        try constructor(repeat resolver.nonisolatedGet((each Dependency).self))
    }.withDependencies(edges)
}

public func nonisolatedFactory<Service: Sendable, Arguments: Sendable, each Dependency: Sendable>(
    _ type: Service.Type, arguments: Arguments.Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @Sendable (Arguments, repeat each Dependency) throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    return nonisolatedFactory(type, arguments: arguments, qualifier: qualifier, fileID: fileID, line: line) { resolver, arguments in
        try constructor(arguments, repeat resolver.nonisolatedGet((each Dependency).self))
    }.withDependencies(edges)
}

// Swift 6.0 misdiagnoses pack arguments passed directly to @isolated(any) functions.
// Async function conversion preserves runtime isolation while avoiding that static crossing.
@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorSingle<Service: Sendable, Isolation: GlobalActor, each Dependency: Sendable>(
    _ type: Service.Type, isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@isolated(any) @Sendable (Service) async -> Void)? = nil,
    fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @isolated(any) @Sendable (repeat each Dependency) async throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    let actualActorID = constructor.isolation.map(ObjectIdentifier.init)
    let callable: @Sendable (repeat each Dependency) async throws -> Service = constructor
    return actorSingle(type, isolatedTo: isolatedTo, qualifier: qualifier, onClose: onClose,
                       fileID: fileID, line: line) { resolver in
        try await callable(repeat resolver.actorGet((each Dependency).self))
    }.withDependencies(edges).withActualActorID(actualActorID)
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorFactory<Service: Sendable, Isolation: GlobalActor, each Dependency: Sendable>(
    _ type: Service.Type, isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @isolated(any) @Sendable (repeat each Dependency) async throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    let actualActorID = constructor.isolation.map(ObjectIdentifier.init)
    let callable: @Sendable (repeat each Dependency) async throws -> Service = constructor
    return actorFactory(type, isolatedTo: isolatedTo, qualifier: qualifier, fileID: fileID, line: line) { resolver in
        try await callable(repeat resolver.actorGet((each Dependency).self))
    }.withDependencies(edges).withActualActorID(actualActorID)
}

@available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
public func actorFactory<Service: Sendable, Arguments: Sendable, Isolation: GlobalActor, each Dependency: Sendable>(
    _ type: Service.Type, arguments: Arguments.Type, isolatedTo: Isolation.Type,
    qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line,
    using constructor: @escaping @isolated(any) @Sendable (Arguments, repeat each Dependency) async throws -> Service
) -> Binding {
    var edges: [BindingDependency] = []
    for dependency in repeat (each Dependency).self { edges.append(.init(dependency)) }
    let actualActorID = constructor.isolation.map(ObjectIdentifier.init)
    let callable: @Sendable (Arguments, repeat each Dependency) async throws -> Service = constructor
    return actorFactory(type, arguments: arguments, isolatedTo: isolatedTo, qualifier: qualifier,
                        fileID: fileID, line: line) { resolver, arguments in
        try await callable(arguments, repeat resolver.actorGet((each Dependency).self))
    }.withDependencies(edges).withActualActorID(actualActorID)
}

private extension Binding {
    func withDependencies(_ dependencies: [BindingDependency]) -> Binding {
        Binding(key: key, lifetime: lifetime, isolation: isolation, provider: provider,
                disposer: disposer, source: source, dependencies: dependencies,
                rootPolicy: rootPolicy, rootSource: rootSource)
    }

    func withActualActorID(_ actualActorID: ObjectIdentifier?) -> Binding {
        let replacement: BindingProvider
        switch provider {
            case let .customActor(storage):
                replacement = .customActor(.init(expectedActorID: storage.expectedActorID,
                                                 actualActorID: actualActorID,
                                                 actorName: storage.actorName,
                                                 invoke: storage.invoke))
            case let .customActorAssisted(storage):
                replacement = .customActorAssisted(.init(expectedActorID: storage.expectedActorID,
                                                         actualActorID: actualActorID,
                                                         actorName: storage.actorName,
                                                         invoke: storage.invoke))
            default: replacement = provider
        }
        return Binding(key: key, lifetime: lifetime, isolation: isolation, provider: replacement,
                       disposer: disposer, source: source, dependencies: dependencies,
                       rootPolicy: rootPolicy, rootSource: rootSource)
    }
}
