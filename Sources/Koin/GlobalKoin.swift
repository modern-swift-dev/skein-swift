import Foundation

package enum GlobalKoin {
    package static let lock = NSRecursiveLock()
    package nonisolated(unsafe) static var application: KoinApplication?
}

public var isKoinStarted: Bool {
    GlobalKoin.lock.withLock { GlobalKoin.application != nil }
}

public func startKoin(@KoinApplicationBuilder _ configure: () -> [Module]) throws {
    let application = try KoinApplication { configure() }
    try GlobalKoin.lock.withLock {
        guard GlobalKoin.application == nil else {
            throw KoinError.alreadyStarted
        }
        GlobalKoin.application = application
    }
}

/// Starts the global application only when one is not already installed.
/// Exactly one concurrent caller constructs and publishes an application.
@discardableResult public func startKoinIfNeeded(
    @KoinApplicationBuilder _ configure: () -> [Module]
) throws -> Bool {
    try GlobalKoin.lock.withLock {
        guard GlobalKoin.application == nil else {
            return false
        }
        let application = try KoinApplication { configure() }
        guard GlobalKoin.application == nil else {
            return false
        }
        GlobalKoin.application = application
        return true
    }
}

public func get<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any KoinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalKoin.lock.withLock({ GlobalKoin.application }) else {
        throw KoinError.notStarted
    }
    return try application.get(type, qualifier: qualifier)
}

public func get<Service>(
    _ type: Service.Type = Service.self,
    arguments: some Any,
    qualifier: (any KoinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalKoin.lock.withLock({ GlobalKoin.application }) else {
        throw KoinError.notStarted
    }
    return try application.get(type, arguments: arguments, qualifier: qualifier)
}

@MainActor public func mainActorGet<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any KoinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalKoin.lock.withLock({ GlobalKoin.application }) else {
        throw KoinError.notStarted
    }
    return try application.mainActorGet(type, qualifier: qualifier)
}

@MainActor public func mainActorGet<Service>(
    _ type: Service.Type = Service.self,
    arguments: some Any,
    qualifier: (any KoinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalKoin.lock.withLock({ GlobalKoin.application }) else {
        throw KoinError.notStarted
    }
    return try application.mainActorGet(type, arguments: arguments, qualifier: qualifier)
}

public struct DependencyProbe {
    private let resolve: @MainActor (any Resolver) throws -> Void

    public init<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)? = nil
    ) {
        resolve = { resolver in
            let _: Service = try resolver.mainActorGet(type, qualifier: qualifier)
        }
    }

    @MainActor package func validate(in resolver: any Resolver) throws {
        try resolve(resolver)
    }
}

@MainActor public func startKoin(
    validating manifest: [DependencyProbe],
    @KoinApplicationBuilder _ configure: () -> [Module]
) throws {
    guard GlobalKoin.lock.withLock({ GlobalKoin.application == nil }) else {
        throw KoinError.alreadyStarted
    }
    let candidate = try KoinApplication(validating: manifest) { configure() }
    try GlobalKoin.lock.withLock {
        guard GlobalKoin.application == nil else {
            throw KoinError.alreadyStarted
        }
        GlobalKoin.application = candidate
    }
}

public func stopKoin() {
    GlobalKoin.lock.withLock { GlobalKoin.application = nil }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) public func stopKoinAndClose() async {
    let application = GlobalKoin.lock.withLock {
        let application = GlobalKoin.application
        GlobalKoin.application = nil
        return application
    }
    await application?.close()
}
