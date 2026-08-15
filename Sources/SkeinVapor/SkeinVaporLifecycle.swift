#if os(macOS) || os(Linux)
import Skein
import Vapor

struct SkeinVaporLifecycle: LifecycleHandler {
    let application: SkeinApplication

    func shutdown(_ application: Application) {
        application.logger.warning(
            "Skein requires Vapor's asyncShutdown() for deterministic resource disposal."
        )
    }

    func shutdownAsync(_ application: Application) async {
        await self.application.close()
    }
}
#endif
