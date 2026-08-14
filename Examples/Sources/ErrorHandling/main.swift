import Koin

enum ConnectionError: Error {
    case unavailable
}

final class Attempts {
    var count = 0
}

let attempts = Attempts()
let retryModule = module {
    single(String.self) { _ in
        attempts.count += 1
        guard attempts.count > 1 else {
            throw ConnectionError.unavailable
        }
        return "connected"
    }
}

do {
    let _: Int = try get()
} catch KoinError.notStarted {
    print("Resolution requires an active container")
} catch {
    print("Unexpected pre-start error: \(error)")
}

do {
    try startKoin {
        modules(retryModule)
    }
    defer { stopKoin() }

    do {
        let _: String = try get()
    } catch let error as KoinResolutionError {
        if error.underlying is ConnectionError {
            print("Provider error retained as the diagnostic underlying error")
        }
    }

    // A failed singleton is not cached, so its provider is tried again.
    let connection: String = try get()
    print("Second attempt: \(connection)")

    do {
        let _: Int = try get()
    } catch let error as KoinResolutionError {
        if case let KoinError.missingBinding(type, qualifier) = error.underlying {
            print("Missing binding for \(type), qualifier: \(qualifier ?? "none")")
        }
    }
} catch {
    print("Koin setup or resolution failed: \(error)")
}
