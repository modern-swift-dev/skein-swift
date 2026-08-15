import Skein

let attempts = Attempts()
let retryModule = module {
    single(String.self, provider: { _ in
        attempts.count += 1
        guard attempts.count > 1 else {
            throw ConnectionError.unavailable
        }
        return "connected"
    })
}

do {
    let _: Int = try get()
} catch SkeinError.notStarted {
    print("Resolution requires an active container")
} catch {
    print("Unexpected pre-start error: \(error)")
}

do {
    try startSkein {
        retryModule
    }
    defer { stopSkein() }

    do {
        let _: String = try get()
    } catch let error as SkeinResolutionError {
        if error.underlying is ConnectionError {
            print("Provider error retained as the diagnostic underlying error")
        }
    }

    // A failed singleton is not cached, so its provider is tried again.
    let connection: String = try get()
    print("Second attempt: \(connection)")

    do {
        let _: Int = try get()
    } catch let error as SkeinResolutionError {
        if case let SkeinError.missingBinding(type, qualifier) = error.underlying {
            print("Missing binding for \(type), qualifier: \(qualifier ?? "none")")
        }
    }
} catch {
    print("Skein setup or resolution failed: \(error)")
}
