import Skein

final class Logger {
    func write(_ message: String) {
        print("[log] \(message)")
    }
}

final class RequestHandler {
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func handle(_ path: String) {
        logger.write("Handling \(path)")
    }
}

struct RequestPath {
    let value: String
}

struct RequestScope: SkeinScope {}

final class RequestCache {}

final class RequestPresenter {
    let path: RequestPath

    init(path: RequestPath) {
        self.path = path
    }
}

let applicationModule = module {
    // Created lazily on the first resolution, then reused.
    single(Logger.self) { _ in Logger() }

    // Created again for each resolution.
    factory(RequestHandler.self) { resolver in
        RequestHandler(logger: try resolver.get())
    }

    // Assisted factories accept one strongly typed runtime value.
    factory(RequestPresenter.self, arguments: RequestPath.self) { _, path in
        RequestPresenter(path: path)
    }

    // Scoped values are shared only by one typed scope instance.
    scoped(RequestCache.self, scope: RequestScope.self) { _ in RequestCache() }
}

do {
    let application = try SkeinApplication {
        modules(applicationModule)
    }

    let firstLogger: Logger = try application.get()
    let secondLogger: Logger = try application.get()
    print("Singleton reused: \(firstLogger === secondLogger)")

    let firstHandler: RequestHandler = try application.get()
    let secondHandler: RequestHandler = try application.get()
    print("Factory creates new values: \(firstHandler !== secondHandler)")
    print("Nested singleton reused: \(firstHandler.logger === secondHandler.logger)")

    firstHandler.handle("/examples")

    let presenter: RequestPresenter = try application.get(
        arguments: RequestPath(value: "/examples")
    )
    print("Assisted path: \(presenter.path.value)")

    let scope = try application.createScope(RequestScope.self, id: "example")
    let firstCache: RequestCache = try scope.get()
    let secondCache: RequestCache = try scope.get()
    print("Scoped cache reused: \(firstCache === secondCache)")
} catch {
    print("Skein setup or resolution failed: \(error)")
}
