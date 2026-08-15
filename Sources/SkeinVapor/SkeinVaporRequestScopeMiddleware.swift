#if os(macOS) || os(Linux)
import Skein
import Vapor

struct SkeinVaporRequestScopeMiddleware: AsyncMiddleware {
    let application: SkeinApplication

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let scope = try application.createScope(
            VaporRequestScope.self,
            id: ObjectIdentifier(request),
            seeding: request
        )
        request.storage[SkeinRequestScopeStorageKey.self] = scope

        do {
            let response = try await next.respond(to: request)
            request.storage[SkeinRequestScopeStorageKey.self] = nil
            await scope.close()
            return response
        } catch {
            request.storage[SkeinRequestScopeStorageKey.self] = nil
            await scope.close()
            throw error
        }
    }
}
#endif
