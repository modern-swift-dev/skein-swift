#if os(macOS) || os(Linux)
import Foundation

/// Errors produced by the Vapor integration layer.
public enum SkeinVaporError: Error, Equatable, LocalizedError {
    /// The Vapor application has not installed a Skein application.
    case applicationNotInitialized
    /// The Vapor application has already installed a Skein application.
    case applicationAlreadyInitialized
    /// No active Skein request scope is available.
    case requestScopeUnavailable

    /// A localized description suitable for logs and diagnostics.
    public var errorDescription: String? {
        switch self {
            case .applicationNotInitialized:
                "Skein has not been initialized for this Vapor application. Call app.skein.initialize { ... } during configuration."
            case .applicationAlreadyInitialized:
                "Skein has already been initialized for this Vapor application."
            case .requestScopeUnavailable:
                "No active Skein request scope is available. Resolve request-scoped services from Vapor's middleware and route handler chain."
        }
    }
}
#endif
