#if os(macOS) || os(Linux)
import Vapor

public extension Application {
    /// Configures and resolves services from this Vapor application's Skein container.
    ///
    /// Call ``SkeinVaporApplication/initialize(validation:_:)`` once during
    /// application configuration before resolving services.
    var skein: SkeinVaporApplication {
        SkeinVaporApplication(application: self)
    }
}
#endif
