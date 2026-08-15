#if os(macOS) || os(Linux)
import Vapor

public extension Request {
    /// Resolves services from this request's middleware-managed Skein scope.
    ///
    /// This accessor is available on every request, but resolution succeeds only
    /// while Skein's request middleware is handling the request.
    var skein: SkeinVaporRequest {
        SkeinVaporRequest(request: self)
    }
}
#endif
