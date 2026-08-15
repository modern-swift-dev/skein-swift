final class RequestHandler {
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func handle(_ path: String) {
        logger.write("Handling \(path)")
    }
}
