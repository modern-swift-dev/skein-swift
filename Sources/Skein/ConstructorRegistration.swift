private func constructorBinding<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)?,
    lifetime: BindingLifetime,
    source: SkeinSourceLocation,
    dependencies: [BindingDependency],
    onClose: ((Service) async -> Void)? = nil,
    provider: @escaping (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: lifetime,
        provider: .standard { try provider($0) },
        disposer: onClose.map { callback in
            .standard { value in
                guard let service = value as? Service else {
                    return
                }
                await callback(service)
            }
        },
        source: source,
        dependencies: dependencies
    )
}

private func mainActorConstructorBinding<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)?,
    lifetime: BindingLifetime,
    source: SkeinSourceLocation,
    dependencies: [BindingDependency],
    onClose: (@MainActor (Service) async -> Void)? = nil,
    provider: @escaping @MainActor (any Resolver) throws -> Service
) -> Binding {
    Binding(
        key: BindingKey(type, qualifier: qualifier),
        lifetime: lifetime,
        provider: .mainActor { try provider($0) },
        disposer: onClose.map { callback in
            .mainActor { value in
                guard let service = value.value as? Service else {
                    return
                }
                await callback(service)
            }
        },
        source: source,
        dependencies: dependencies
    )
}

// MARK: Standard constructor registrations

public func single<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping () throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .single, source: .init(fileID: fileID, line: line), dependencies: [], onClose: onClose) { _ in try constructor() }
}

public func single<Service, D1>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1) throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .single, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self)], onClose: onClose) { try constructor($0.get(D1.self)) }
}

public func single<Service, D1, D2>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1, D2) throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .single, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self)], onClose: onClose) { try constructor(
        $0.get(D1.self),
        $0.get(D2.self)
    ) }
}

public func single<Service, D1, D2, D3>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1, D2, D3) throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .single, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self), .init(D3.self)], onClose: onClose) {
        try constructor(
            $0.get(D1.self),
            $0.get(D2.self),
            $0.get(D3.self)
        )
    }
}

public func single<Service, D1, D2, D3, D4>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: ((Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1, D2, D3, D4) throws -> Service
) -> Binding {
    constructorBinding(
        type,
        qualifier: qualifier,
        lifetime: .single,
        source: .init(fileID: fileID, line: line),
        dependencies: [.init(D1.self), .init(D2.self), .init(D3.self), .init(D4.self)],
        onClose: onClose
    ) { try constructor($0.get(D1.self), $0.get(D2.self), $0.get(D3.self), $0.get(D4.self)) }
}

public func factory<Service>(_ type: Service.Type, qualifier: (any SkeinQualifier)? = nil, fileID: String = #fileID, line: UInt = #line, using constructor: @escaping () throws -> Service) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: []) { _ in try constructor() }
}

public func factory<Service, D1>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1) throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self)]) { try constructor($0.get(D1.self)) }
}

public func factory<Service, D1, D2>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1, D2) throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self)]) { try constructor(
        $0.get(D1.self),
        $0.get(D2.self)
    ) }
}

public func factory<Service, D1, D2, D3>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1, D2, D3) throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self), .init(D3.self)]) { try constructor(
        $0.get(D1.self),
        $0.get(D2.self),
        $0.get(D3.self)
    ) }
}

public func factory<Service, D1, D2, D3, D4>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping (D1, D2, D3, D4) throws -> Service
) -> Binding {
    constructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self), .init(D3.self), .init(D4.self)]) {
        try constructor(
            $0.get(D1.self),
            $0.get(D2.self),
            $0.get(D3.self),
            $0.get(D4.self)
        )
    }
}

// MARK: Main-actor constructor registrations

public func mainActorSingle<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor () throws -> Service
) -> Binding {
    mainActorConstructorBinding(type, qualifier: qualifier, lifetime: .single, source: .init(fileID: fileID, line: line), dependencies: [], onClose: onClose) { _ in try constructor() }
}

public func mainActorSingle<Service, D1>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1) throws -> Service
) -> Binding {
    mainActorConstructorBinding(type, qualifier: qualifier, lifetime: .single, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self)], onClose: onClose) {
        try constructor($0.mainActorGet(D1.self))
    }
}

public func mainActorSingle<Service, D1, D2>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1, D2) throws -> Service
) -> Binding {
    mainActorConstructorBinding(type, qualifier: qualifier, lifetime: .single, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self)], onClose: onClose) {
        try constructor(
            $0.mainActorGet(D1.self),
            $0.mainActorGet(D2.self)
        )
    }
}

public func mainActorSingle<Service, D1, D2, D3>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1, D2, D3) throws -> Service
) -> Binding {
    mainActorConstructorBinding(
        type,
        qualifier: qualifier,
        lifetime: .single,
        source: .init(fileID: fileID, line: line),
        dependencies: [.init(D1.self), .init(D2.self), .init(D3.self)],
        onClose: onClose
    ) { try constructor($0.mainActorGet(D1.self), $0.mainActorGet(D2.self), $0.mainActorGet(D3.self)) }
}

public func mainActorSingle<Service, D1, D2, D3, D4>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    onClose: (@MainActor (Service) async -> Void)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1, D2, D3, D4) throws -> Service
) -> Binding {
    mainActorConstructorBinding(
        type,
        qualifier: qualifier,
        lifetime: .single,
        source: .init(fileID: fileID, line: line),
        dependencies: [.init(D1.self), .init(D2.self), .init(D3.self), .init(D4.self)],
        onClose: onClose
    ) { try constructor($0.mainActorGet(D1.self), $0.mainActorGet(D2.self), $0.mainActorGet(D3.self), $0.mainActorGet(D4.self)) }
}

public func mainActorFactory<Service>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor () throws -> Service
) -> Binding {
    mainActorConstructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: []) { _ in try constructor() }
}

public func mainActorFactory<Service, D1>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1) throws -> Service
) -> Binding {
    mainActorConstructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self)]) { try constructor($0.mainActorGet(D1.self)) }
}

public func mainActorFactory<Service, D1, D2>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1, D2) throws -> Service
) -> Binding {
    mainActorConstructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self)]) { try constructor(
        $0.mainActorGet(D1.self),
        $0.mainActorGet(D2.self)
    ) }
}

public func mainActorFactory<Service, D1, D2, D3>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1, D2, D3) throws -> Service
) -> Binding {
    mainActorConstructorBinding(type, qualifier: qualifier, lifetime: .factory, source: .init(fileID: fileID, line: line), dependencies: [.init(D1.self), .init(D2.self), .init(D3.self)]) {
        try constructor(
            $0.mainActorGet(D1.self),
            $0.mainActorGet(D2.self),
            $0.mainActorGet(D3.self)
        )
    }
}

public func mainActorFactory<Service, D1, D2, D3, D4>(
    _ type: Service.Type,
    qualifier: (any SkeinQualifier)? = nil,
    fileID: String = #fileID,
    line: UInt = #line,
    using constructor: @escaping @MainActor (D1, D2, D3, D4) throws -> Service
) -> Binding {
    mainActorConstructorBinding(
        type,
        qualifier: qualifier,
        lifetime: .factory,
        source: .init(fileID: fileID, line: line),
        dependencies: [.init(D1.self), .init(D2.self), .init(D3.self), .init(D4.self)]
    ) { try constructor($0.mainActorGet(D1.self), $0.mainActorGet(D2.self), $0.mainActorGet(D3.self), $0.mainActorGet(D4.self)) }
}
