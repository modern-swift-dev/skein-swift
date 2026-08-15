import Foundation

/// Stores the process-wide Skein application lifecycle state.
package enum GlobalSkein {
    /// A validated startup operation that has not yet completed.
    package struct Startup: @unchecked Sendable {
        let token: UUID
        let task: Task<SkeinApplication, Error>
    }

    /// The current process-wide application lifecycle state.
    package enum State: @unchecked Sendable {
        /// No application is installed and no startup is running.
        case idle
        /// A validated startup task is running.
        case starting(Startup)
        /// An application is installed and ready for resolution.
        case started(SkeinApplication)
    }

    /// Serializes access to the process-wide lifecycle state.
    package static let lock = NSRecursiveLock()
    /// The process-wide lifecycle state protected by ``lock``.
    package nonisolated(unsafe) static var state: State = .idle
}

/// Whether the process-wide Skein application has completed startup.
public var isSkeinStarted: Bool {
    GlobalSkein.lock.withLock {
        if case .started = GlobalSkein.state {
            true
        } else {
            false
        }
    }
}

/// The report produced by validated process-wide startup, when available.
public var currentSkeinValidationReport: GraphValidationReport? {
    GlobalSkein.lock.withLock {
        guard case let .started(application) = GlobalSkein.state else {
            return nil
        }
        return application.startupValidationReport
    }
}

/// Installs the process-wide Skein application on the main actor.
///
/// - Parameter configure: The builder that declares the application's modules.
/// - Throws: ``SkeinError/alreadyStarted`` when an application is already installed,
///   or a configuration error while constructing the application.
@MainActor public func startSkein(
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) throws {
    let application = try SkeinApplication { configure() }
    try GlobalSkein.lock.withLock {
        guard case .idle = GlobalSkein.state else {
            throw SkeinError.alreadyStarted
        }
        GlobalSkein.state = .started(application)
    }
}

/// Installs the process-wide Skein application if startup has not occurred.
///
/// - Parameter configure: The builder that declares the application's modules.
/// - Returns: `true` when this call installed the application; otherwise `false`.
/// - Throws: A configuration error while constructing the application.
@discardableResult
@MainActor public func startSkeinIfNeeded(
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) throws -> Bool {
    try GlobalSkein.lock.withLock {
        guard case .idle = GlobalSkein.state else {
            return false
        }
        GlobalSkein.state = .started(try SkeinApplication { configure() })
        return true
    }
}

/// Builds, validates, and installs the process-wide Skein application.
///
/// - Parameters:
///   - validation: The startup validation policy.
///   - configure: The builder that declares the application's modules.
/// - Throws: ``SkeinError/alreadyStarted`` when another application is installed
///   or starting, or an error produced by construction or validation.
@MainActor public func startSkein(
    validation: ValidationPolicy,
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) async throws {
    let owner = try beginValidatedStartup(validation: validation, configure)
    guard owner.isOwner else {
        throw SkeinError.alreadyStarted
    }
    _ = try await owner.task.value
}

/// Concurrent callers share the same startup task. Only the caller that
/// evaluated the application builder reports that it performed startup.
///
/// - Parameters:
///   - validation: The startup validation policy.
///   - configure: The builder that declares the application's modules.
/// - Returns: `true` when this call created the shared startup task; otherwise `false`.
/// - Throws: An error produced by application construction or validation.
@discardableResult
@MainActor public func startSkeinIfNeeded(
    validation: ValidationPolicy,
    @SkeinApplicationBuilder _ configure: @MainActor () -> [Module]
) async throws -> Bool {
    let startup = try beginValidatedStartup(validation: validation, configure)
    _ = try await startup.task.value
    return startup.isOwner
}

@MainActor private func beginValidatedStartup(
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
                      startup.token == token else {
                    return false
                }
                GlobalSkein.state = .started(candidate)
                return true
            }
            guard published else {
                throw CancellationError()
            }
            return candidate
        } catch {
            GlobalSkein.lock.withLock {
                guard case let .starting(startup) = GlobalSkein.state,
                      startup.token == token else {
                    return
                }
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

/// Resolves a main-actor service from the process-wide application.
///
/// - Parameters:
///   - type: The service type to resolve.
///   - qualifier: The qualifier selecting the binding, or `nil`.
/// - Returns: The resolved service.
/// - Throws: ``SkeinError/notStarted`` or a resolution error.
@MainActor public func get<Service>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().get(type, qualifier: qualifier)
}

/// Resolves an assisted main-actor service from the process-wide application.
///
/// - Parameters:
///   - type: The service type to resolve.
///   - arguments: The assisted arguments passed to the provider.
///   - qualifier: The qualifier selecting the binding, or `nil`.
/// - Returns: The resolved service.
/// - Throws: ``SkeinError/notStarted`` or a resolution error.
@MainActor public func get<Service>(
    _ type: Service.Type = Service.self,
    arguments: some Any,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().get(type, arguments: arguments, qualifier: qualifier)
}

/// Resolves a sendable nonisolated service from the process-wide application.
///
/// - Parameters:
///   - type: The service type to resolve.
///   - qualifier: The qualifier selecting the binding, or `nil`.
/// - Returns: The resolved service.
/// - Throws: ``SkeinError/notStarted`` or a resolution error.
public func nonisolatedGet<Service: Sendable>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().nonisolatedGet(type, qualifier: qualifier)
}

/// Resolves an assisted sendable nonisolated service from the process-wide application.
///
/// - Parameters:
///   - type: The service type to resolve.
///   - arguments: The assisted arguments passed to the provider.
///   - qualifier: The qualifier selecting the binding, or `nil`.
/// - Returns: The resolved service.
/// - Throws: ``SkeinError/notStarted`` or a resolution error.
public func nonisolatedGet<Service: Sendable>(
    _ type: Service.Type = Service.self,
    arguments: some Sendable,
    qualifier: (any SkeinQualifier)? = nil
) throws -> Service {
    try installedApplication().nonisolatedGet(type, arguments: arguments, qualifier: qualifier)
}

/// Resolves a service on its registered custom actor.
///
/// - Parameters:
///   - type: The service type to resolve.
///   - qualifier: The qualifier selecting the binding, or `nil`.
/// - Returns: The resolved service.
/// - Throws: ``SkeinError/notStarted`` or a resolution error.
public func actorGet<Service: Sendable>(
    _ type: Service.Type = Service.self,
    qualifier: (any SkeinQualifier)? = nil
) async throws -> Service {
    try await installedApplication().actorGet(type, qualifier: qualifier)
}

/// Resolves an assisted service on its registered custom actor.
///
/// - Parameters:
///   - type: The service type to resolve.
///   - arguments: The assisted arguments passed to the provider.
///   - qualifier: The qualifier selecting the binding, or `nil`.
/// - Returns: The resolved service.
/// - Throws: ``SkeinError/notStarted`` or a resolution error.
public func actorGet<Service: Sendable>(
    _ type: Service.Type = Service.self,
    arguments: some Sendable,
    qualifier: (any SkeinQualifier)? = nil
) async throws -> Service {
    try await installedApplication().actorGet(type, arguments: arguments, qualifier: qualifier)
}

private func installedApplication() throws -> SkeinApplication {
    let snapshot: SkeinApplication? = GlobalSkein.lock.withLock {
        guard case let .started(application) = GlobalSkein.state else {
            return nil
        }
        return application
    }
    guard let application = snapshot else {
        throw SkeinError.notStarted
    }
    return application
}

/// Stops process-wide resolution and cancels validated startup if it is running.
///
/// This operation does not run disposal callbacks for an installed application.
@MainActor public func stopSkein() {
    let startup = GlobalSkein.lock.withLock { () -> GlobalSkein.Startup? in
        defer { GlobalSkein.state = .idle }
        guard case let .starting(startup) = GlobalSkein.state else {
            return nil
        }
        return startup
    }
    startup?.task.cancel()
}

/// Stops the process-wide application and awaits its disposal callbacks.
///
/// A validated startup still in progress is cancelled instead.
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
