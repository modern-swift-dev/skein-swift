import Foundation

package enum GlobalSkein {
    package static let lock = NSRecursiveLock()
    package nonisolated(unsafe) static var application: SkeinApplication?
}

public var isSkeinStarted: Bool {
    GlobalSkein.lock.withLock { GlobalSkein.application != nil }
}

public func startSkein(@SkeinApplicationBuilder _ configure: () -> [Module]) throws {
    let application = try SkeinApplication { configure() }
    try GlobalSkein.lock.withLock {
        guard GlobalSkein.application == nil else {
            throw SkeinError.alreadyStarted
        }
        GlobalSkein.application = application
    }
}

/// Starts the global application only when one is not already installed.
/// Exactly one concurrent caller constructs and publishes an application.
@discardableResult public func startSkeinIfNeeded(
    @SkeinApplicationBuilder _ configure: () -> [Module]
) throws -> Bool {
    try GlobalSkein.lock.withLock {
        guard GlobalSkein.application == nil else {
            return false
        }
        let application = try SkeinApplication { configure() }
        guard GlobalSkein.application == nil else {
            return false
        }
        GlobalSkein.application = application
        return true
    }
}

public func get<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalSkein.lock.withLock({ GlobalSkein.application }) else {
        throw SkeinError.notStarted
    }
    return try application.get(type, qualifier: qualifier)
}

public func get<Service>(
    _ type: Service.Type = Service.self,
    arguments: some Any,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalSkein.lock.withLock({ GlobalSkein.application }) else {
        throw SkeinError.notStarted
    }
    return try application.get(type, arguments: arguments, qualifier: qualifier)
}

@MainActor public func mainActorGet<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalSkein.lock.withLock({ GlobalSkein.application }) else {
        throw SkeinError.notStarted
    }
    return try application.mainActorGet(type, qualifier: qualifier)
}

@MainActor public func mainActorGet<Service>(
    _ type: Service.Type = Service.self,
    arguments: some Any,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    guard let application = GlobalSkein.lock.withLock({ GlobalSkein.application }) else {
        throw SkeinError.notStarted
    }
    return try application.mainActorGet(type, arguments: arguments, qualifier: qualifier)
}

public struct DependencyProbe {
    private let resolve: @MainActor (any Resolver) throws -> Void

    public init<Service>(
        _ type: Service.Type,
        qualifier: (any SkeinQualifier)? = nil
    ) {
        resolve = { resolver in
            let _: Service = try resolver.mainActorGet(type, qualifier: qualifier)
        }
    }

    @MainActor package func validate(in resolver: any Resolver) throws {
        try resolve(resolver)
    }
}

@MainActor public func startSkein(
    validating manifest: [DependencyProbe],
    @SkeinApplicationBuilder _ configure: () -> [Module]
) throws {
    guard GlobalSkein.lock.withLock({ GlobalSkein.application == nil }) else {
        throw SkeinError.alreadyStarted
    }
    let candidate = try SkeinApplication(validating: manifest) { configure() }
    try GlobalSkein.lock.withLock {
        guard GlobalSkein.application == nil else {
            throw SkeinError.alreadyStarted
        }
        GlobalSkein.application = candidate
    }
}

public func stopSkein() {
    GlobalSkein.lock.withLock { GlobalSkein.application = nil }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *) public func stopSkeinAndClose() async {
    let application = GlobalSkein.lock.withLock {
        let application = GlobalSkein.application
        GlobalSkein.application = nil
        return application
    }
    await application?.close()
}
