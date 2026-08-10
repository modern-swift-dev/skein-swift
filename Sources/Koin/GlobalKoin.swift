import Foundation

package enum GlobalKoin {
    package static let lock = NSLock()
    package nonisolated(unsafe) static var container: Container?
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

/// Stops the global Koin container. Calling this when stopped has no effect.
public func stopKoin() {
    GlobalKoin.lock.lock()
    GlobalKoin.container = nil
    GlobalKoin.lock.unlock()
}
