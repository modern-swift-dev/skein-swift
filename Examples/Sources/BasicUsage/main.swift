import Koin

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

let applicationModule = module {
    // Created lazily on the first resolution, then reused.
    single(Logger.self) { _ in Logger() }

    // Created again for each resolution.
    factory(RequestHandler.self) { resolver in
        RequestHandler(logger: try resolver.get())
    }
}

do {
    try startKoin {
        modules(applicationModule)
    }
    defer { stopKoin() }

    let firstLogger: Logger = try get()
    let secondLogger: Logger = try get()
    print("Singleton reused: \(firstLogger === secondLogger)")

    let firstHandler: RequestHandler = try get()
    let secondHandler: RequestHandler = try get()
    print("Factory creates new values: \(firstHandler !== secondHandler)")
    print("Nested singleton reused: \(firstHandler.logger === secondHandler.logger)")

    firstHandler.handle("/examples")
} catch {
    print("Koin setup or resolution failed: \(error)")
}
