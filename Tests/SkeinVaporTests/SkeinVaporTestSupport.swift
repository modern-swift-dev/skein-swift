#if os(macOS) || os(Linux)
import Vapor

func makeRequest(
    application: Application,
    headers: HTTPHeaders = .init()
) -> Request {
    Request(
        application: application,
        headers: headers,
        on: application.eventLoopGroup.next()
    )
}
#endif
