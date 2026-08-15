#if os(macOS) || os(Linux)
import SkeinVapor
import Vapor

struct ScopeProbeMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let _: RequestService = try request.skein.get()
        return try await next.respond(to: request)
    }
}
#endif
