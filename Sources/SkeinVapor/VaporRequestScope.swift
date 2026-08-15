#if os(macOS) || os(Linux)
import Skein

/// The scope used for services whose lifetime is one Vapor request.
///
/// Register request-lifetime services with this scope and resolve them through
/// `Request.skein` while the request middleware chain is active.
public enum VaporRequestScope: SkeinScope {}
#endif
