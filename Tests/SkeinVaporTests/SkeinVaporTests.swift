#if os(macOS) || os(Linux)
import Skein
import SkeinVapor
import Vapor
import XCTest

@MainActor final class SkeinVaporTests: XCTestCase {
    func testMissingApplicationAndRequestScopeProduceTypedErrors() async throws {
        let app = try await Application.make(.testing)
        let request = makeRequest(application: app)

        XCTAssertThrowsError(try app.skein.get(String.self)) { error in
            XCTAssertEqual(error as? SkeinVaporError, .applicationNotInitialized)
        }
        XCTAssertThrowsError(try request.skein.get(String.self)) { error in
            XCTAssertEqual(error as? SkeinVaporError, .requestScopeUnavailable)
        }

        try await app.asyncShutdown()
    }

    func testDuplicateInitializationFails() async throws {
        let app = try await Application.make(.testing)
        app.middleware = .init()
        try await app.skein.initialize { module {} }

        do {
            try await app.skein.initialize { module {} }
            XCTFail("Expected duplicate initialization to fail")
        } catch {
            XCTAssertEqual(error as? SkeinVaporError, .applicationAlreadyInitialized)
        }

        try await app.asyncShutdown()
    }

    func testRequestScopeInjectsRequestAndCachesPerRequest() async throws {
        let app = try await Application.make(.testing)
        app.middleware = .init()
        let recorder = DisposalRecorder()
        try await app.skein.initialize {
            module {
                nonisolatedScoped(
                    RequestService.self,
                    scope: VaporRequestScope.self,
                    onClose: { service in await recorder.append(service.id) },
                    provider: { resolver in
                        RequestService(request: try resolver.nonisolatedGet(Request.self))
                    }
                )
            }
        }
        let responder = app.middleware.resolve().makeResponder(
            chainingTo: ClosureResponder { request in
                let first: RequestService = try request.skein.get()
                let second: RequestService = try request.skein.get()
                guard first.id == second.id, first.request === request else {
                    throw ThrowingResponderError()
                }
                return Response(body: .init(string: first.id.uuidString))
            }
        )

        let first = try await responder.respond(to: makeRequest(application: app)).get()
        let second = try await responder.respond(to: makeRequest(application: app)).get()

        XCTAssertNotEqual(first.body.string, second.body.string)
        let disposalCount = await recorder.snapshot().count
        XCTAssertEqual(disposalCount, 2)
        try await app.asyncShutdown()
    }

    func testRequestScopeClosesWhenDownstreamThrows() async throws {
        let app = try await Application.make(.testing)
        app.middleware = .init()
        let recorder = DisposalRecorder()
        try await app.skein.initialize {
            module {
                nonisolatedScoped(
                    RequestService.self,
                    scope: VaporRequestScope.self,
                    onClose: { service in await recorder.append(service.id) },
                    provider: { resolver in
                        RequestService(request: try resolver.nonisolatedGet(Request.self))
                    }
                )
            }
        }
        let responder = app.middleware.resolve().makeResponder(
            chainingTo: ClosureResponder { request in
                let _: RequestService = try request.skein.get()
                throw ThrowingResponderError()
            }
        )

        do {
            _ = try await responder.respond(to: makeRequest(application: app)).get()
            XCTFail("Expected responder to throw")
        } catch is ThrowingResponderError {
            // Expected.
        }

        let disposalCount = await recorder.snapshot().count
        XCTAssertEqual(disposalCount, 1)
        try await app.asyncShutdown()
    }

    func testConcurrentRequestsWithSameRequestIDUseDistinctScopes() async throws {
        let app = try await Application.make(.testing)
        app.middleware = .init()
        try await app.skein.initialize {
            module {
                nonisolatedScoped(RequestService.self, scope: VaporRequestScope.self) { resolver in
                    RequestService(request: try resolver.nonisolatedGet(Request.self))
                }
            }
        }
        let responder = app.middleware.resolve().makeResponder(
            chainingTo: ClosureResponder { request in
                let service: RequestService = try request.skein.get()
                return Response(body: .init(string: service.id.uuidString))
            }
        )
        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: "X-Request-ID", value: "duplicate")
        let firstRequest = makeRequest(application: app, headers: headers)
        let secondRequest = makeRequest(application: app, headers: headers)

        async let firstResponse = responder.respond(to: firstRequest).get()
        async let secondResponse = responder.respond(to: secondRequest).get()
        let responses = try await (firstResponse, secondResponse)

        XCTAssertEqual(firstRequest.id, secondRequest.id)
        XCTAssertNotEqual(responses.0.body.string, responses.1.body.string)
        try await app.asyncShutdown()
    }

    func testScopeMiddlewareIsInstalledBeforeExistingMiddleware() async throws {
        let app = try await Application.make(.testing)
        var middleware = Middlewares()
        middleware.use(ScopeProbeMiddleware())
        app.middleware = middleware
        try await app.skein.initialize {
            module {
                nonisolatedScoped(RequestService.self, scope: VaporRequestScope.self) { resolver in
                    RequestService(request: try resolver.nonisolatedGet(Request.self))
                }
            }
        }
        let responder = app.middleware.resolve().makeResponder(
            chainingTo: ClosureResponder { _ in Response(status: .ok) }
        )

        let response = try await responder.respond(to: makeRequest(application: app)).get()

        XCTAssertEqual(response.status, HTTPStatus.ok)
        try await app.asyncShutdown()
    }

    func testApplicationResolutionForwardsQualifierAssistanceAndActorCalls() async throws {
        let app = try await Application.make(.testing)
        app.middleware = .init()
        try await app.skein.initialize(validation: nil) {
            module {
                nonisolatedFactory(
                    String.self,
                    arguments: Int.self,
                    qualifier: SpecialQualifier.value,
                    provider: { _, value in "value:\(value)" }
                )
                nonisolatedFactory(Bool.self) { _ in true }
            }
        }

        let value: String = try app.skein.get(
            arguments: 42,
            qualifier: SpecialQualifier.value
        )
        let flag: Bool = try await app.skein.actorGet()

        XCTAssertEqual(value, "value:42")
        XCTAssertTrue(flag)
        try await app.asyncShutdown()
    }

    func testRequestResolutionForwardsQualifierAssistanceAndActorCalls() async throws {
        let app = try await Application.make(.testing)
        app.middleware = .init()
        try await app.skein.initialize(validation: nil) {
            module {
                nonisolatedFactory(
                    String.self,
                    arguments: Int.self,
                    qualifier: SpecialQualifier.value,
                    provider: { _, value in "value:\(value)" }
                )
                nonisolatedFactory(Bool.self) { _ in true }
            }
        }
        let responder = app.middleware.resolve().makeResponder(
            chainingTo: ClosureResponder { request in
                let value: String = try request.skein.get(
                    arguments: 42,
                    qualifier: SpecialQualifier.value
                )
                let flag: Bool = try await request.skein.actorGet()
                return Response(body: .init(string: "\(value):\(flag)"))
            }
        )

        let response = try await responder.respond(to: makeRequest(application: app)).get()

        XCTAssertEqual(response.body.string, "value:42:true")
        try await app.asyncShutdown()
    }

    func testVaporShutdownClosesApplicationSingletons() async throws {
        let app = try await Application.make(.testing)
        app.middleware = .init()
        let recorder = DisposalRecorder()
        try await app.skein.initialize {
            module {
                nonisolatedSingle(
                    UUID.self,
                    onClose: { value in await recorder.append(value) },
                    provider: { _ in UUID() }
                )
            }
        }
        let value: UUID = try app.skein.get()

        try await app.asyncShutdown()

        let disposedValues = await recorder.snapshot()
        XCTAssertEqual(disposedValues, [value])
    }
}
#endif
