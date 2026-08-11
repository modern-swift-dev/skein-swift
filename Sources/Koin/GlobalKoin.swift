import Foundation

package enum GlobalKoin {
    package static let lock = NSLock()
    package nonisolated(unsafe) static var container: Container?
}

/// A thread-safe snapshot indicating whether the global Koin container is active.
public var isKoinStarted: Bool {
    GlobalKoin.lock.lock()
    defer { GlobalKoin.lock.unlock() }
    return GlobalKoin.container != nil
}

/// Starts the global Koin container. Only one container may be active at a time.
public func startKoin(@KoinApplicationBuilder _ configure: () -> [Module]) throws {
    let container = try Container(modules: configure())
    GlobalKoin.lock.lock()
    defer { GlobalKoin.lock.unlock() }
    guard GlobalKoin.container == nil else {
        throw KoinError.alreadyStarted
    }
    GlobalKoin.container = container
}

/// Resolves a dependency from the active global Koin container.
public func get<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any KoinQualifier)? = nil
) throws -> Service {
    GlobalKoin.lock.lock()
    let container = GlobalKoin.container
    GlobalKoin.lock.unlock()
    guard let container else {
        throw KoinError.notStarted
    }
    return try container.get(type, qualifier: qualifier)
}

/// Resolves a dependency from the active global Koin container while isolated
/// to the main actor. Both ordinary and main-actor bindings may be resolved.
@MainActor
public func mainActorGet<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any KoinQualifier)? = nil
) throws -> Service {
    GlobalKoin.lock.lock()
    let container = GlobalKoin.container
    GlobalKoin.lock.unlock()
    guard let container else {
        throw KoinError.notStarted
    }
    return try container.mainActorGet(type, qualifier: qualifier)
}

/// A type-erased dependency request used by validated startup.
///
/// Constructing a probe does not resolve its dependency. The dependency is
/// resolved only when the probe is passed to `startKoin(validating:_:)`.
public struct DependencyProbe {
    private let resolve: @MainActor (Container) throws -> Void

    /// Creates a probe for an explicit service type and optional qualifier.
    public init<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)? = nil
    ) {
        resolve = { container in
            let _: Service = try container.mainActorGet(type, qualifier: qualifier)
        }
    }

    @MainActor
    package func validate(in container: Container) throws {
        try resolve(container)
    }
}

/// Builds and validates a candidate global container before publishing it.
///
/// Only dependencies in `manifest` are resolved, in order, and validation
/// stops at the first error. Successful singleton resolutions remain cached in
/// the published container; factories and provider side effects run during
/// validation. A failed candidate is not published, but its external side
/// effects are not rolled back.
@MainActor
public func startKoin(
    validating manifest: [DependencyProbe],
    @KoinApplicationBuilder _ configure: () -> [Module]
) throws {
    GlobalKoin.lock.lock()
    let alreadyStarted = GlobalKoin.container != nil
    GlobalKoin.lock.unlock()
    guard !alreadyStarted else {
        throw KoinError.alreadyStarted
    }

    let candidate = try Container(modules: configure())
    for probe in manifest {
        try probe.validate(in: candidate)
    }

    GlobalKoin.lock.lock()
    defer { GlobalKoin.lock.unlock() }
    guard GlobalKoin.container == nil else {
        throw KoinError.alreadyStarted
    }
    GlobalKoin.container = candidate
}

/// Stops the global Koin container. Calling this when stopped has no effect.
public func stopKoin() {
    GlobalKoin.lock.lock()
    GlobalKoin.container = nil
    GlobalKoin.lock.unlock()
}
