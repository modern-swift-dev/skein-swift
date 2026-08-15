#if os(macOS) || os(Linux)
import Vapor

struct ClosureResponder: AsyncResponder {
    let closure: @Sendable (Request) async throws -> Response

    func respond(to request: Request) async throws -> Response {
        try await closure(request)
    }
}
#endif
