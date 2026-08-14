import Foundation

package enum GlobalSkein {
    package struct Startup: @unchecked Sendable {
        let token: UUID
        let task: Task<SkeinApplication, Error>
    }

    package enum State: @unchecked Sendable {
        case idle
        case starting(Startup)
        case started(SkeinApplication)
    }

    package static let lock = NSRecursiveLock()
    package nonisolated(unsafe) static var state: State = .idle
}

public var isSkeinStarted: Bool {
    GlobalSkein.lock.withLock {
        if case .started = GlobalSkein.state { true } else { false }
    }
}

public var currentSkeinValidationReport: GraphValidationReport? {
    GlobalSkein.lock.withLock {
        guard case let .started(application) = GlobalSkein.state else { return nil }
        return application.startupValidationReport
    }
}

@MainActor public func startSkein(
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) throws {
    let application = try SkeinApplication { configure() }
    try GlobalSkein.lock.withLock {
        guard case .idle = GlobalSkein.state else { throw SkeinError.alreadyStarted }
        GlobalSkein.state = .started(application)
    }
}

@discardableResult
@MainActor public func startSkeinIfNeeded(
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) throws -> Bool {
    try GlobalSkein.lock.withLock {
        guard case .idle = GlobalSkein.state else { return false }
        GlobalSkein.state = .started(try SkeinApplication { configure() })
        return true
    }
}

@MainActor public func startSkein(
    validation: ValidationPolicy,
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) async throws {
    let owner = try beginValidatedStartup(validation: validation, configure)
    guard owner.isOwner else { throw SkeinError.alreadyStarted }
    _ = try await owner.task.value
}

/// Concurrent callers share the same startup task. Only the caller that
/// evaluated the application builder reports that it performed startup.
@discardableResult
@MainActor public func startSkeinIfNeeded(
    validation: ValidationPolicy,
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) async throws -> Bool {
    let startup = try beginValidatedStartup(validation: validation, configure)
    _ = try await startup.task.value
    return startup.isOwner
}

@MainActor
private func beginValidatedStartup(
    validation: ValidationPolicy,
    _ configure: @MainActor () -> [Module]
) throws -> (task: Task<SkeinApplication, Error>, isOwner: Bool) {
    let snapshot = GlobalSkein.lock.withLock { GlobalSkein.state }
    switch snapshot {
        case let .starting(startup): return (startup.task, false)
        case let .started(application): return (Task { application }, false)
        case .idle: break
    }

    // The builder is main-actor isolated and is evaluated exactly once before
    // validation starts. The task itself owns the asynchronous startup work.
    let modules = configure()
    let token = UUID()
    let task = Task<SkeinApplication, Error> { @MainActor in
        do {
            let candidate = try await SkeinApplication(validation: validation) { modules }
            try Task.checkCancellation()
            let published = GlobalSkein.lock.withLock {
                guard case let .starting(startup) = GlobalSkein.state,
                      startup.token == token else { return false }
                GlobalSkein.state = .started(candidate)
                return true
            }
            guard published else { throw CancellationError() }
            return candidate
        } catch {
            GlobalSkein.lock.withLock {
                guard case let .starting(startup) = GlobalSkein.state,
                      startup.token == token else { return }
                GlobalSkein.state = .idle
            }
            throw error
        }
    }
    GlobalSkein.lock.withLock {
        // MainActor serialization means no other builder can race this write;
        // the lock also protects readers on nonisolated resolution surfaces.
        GlobalSkein.state = .starting(.init(token: token, task: task))
    }
    return (task, true)
}

@MainActor public func get<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().get(type, qualifier: qualifier)
}

@MainActor public func get<Service, Arguments>(
    _ type: Service.Type = Service.self,
    arguments: Arguments,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().get(type, arguments: arguments, qualifier: qualifier)
}

public func nonisolatedGet<Service: Sendable>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().nonisolatedGet(type, qualifier: qualifier)
}

public func nonisolatedGet<Service: Sendable, Arguments: Sendable>(
    _ type: Service.Type = Service.self,
    arguments: Arguments,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().nonisolatedGet(type, arguments: arguments, qualifier: qualifier)
}

public func actorGet<Service: Sendable>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) async throws -> Service {
    try await installedApplication().actorGet(type, qualifier: qualifier)
}

public func actorGet<Service: Sendable, Arguments: Sendable>(
    _ type: Service.Type = Service.self,
    arguments: Arguments,
    qualifier: (any SkeinQualifier)? = nil
) async throws -> Service {
    try await installedApplication().actorGet(type, arguments: arguments, qualifier: qualifier)
}

private func installedApplication() throws -> SkeinApplication {
    let snapshot: SkeinApplication? = GlobalSkein.lock.withLock {
        guard case let .started(application) = GlobalSkein.state else { return nil }
        return application
    }
    guard let application = snapshot else { throw SkeinError.notStarted }
    return application
}

@MainActor public func stopSkein() {
    let startup = GlobalSkein.lock.withLock { () -> GlobalSkein.Startup? in
        defer { GlobalSkein.state = .idle }
        guard case let .starting(startup) = GlobalSkein.state else { return nil }
        return startup
    }
    startup?.task.cancel()
}

@MainActor public func stopSkeinAndClose() async {
    let stopped = GlobalSkein.lock.withLock { () -> (SkeinApplication?, GlobalSkein.Startup?) in
        defer { GlobalSkein.state = .idle }
        switch GlobalSkein.state {
            case .idle: return (nil, nil)
            case let .starting(startup): return (nil, startup)
            case let .started(application): return (application, nil)
        }
    }
    stopped.1?.task.cancel()
    await stopped.0?.close()
}
