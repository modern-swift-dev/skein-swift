import Skein

private struct AppConfiguration {
    let apiBaseURL = "https://example.invalid"
}

@MainActor private final class AccountScreenModel {
    let apiBaseURL: String

    init(configuration: AppConfiguration) {
        apiBaseURL = configuration.apiBaseURL
    }
}

@MainActor private let applicationModule = module {
    single(AppConfiguration.self) { _ in AppConfiguration() }

    mainActorSingle(AccountScreenModel.self) { resolver in
        AccountScreenModel(configuration: try resolver.get())
    }
}

@main
@MainActor private struct MainActorValidation {
    static func main() {
        do {
            // The application owns this policy and may log or fail fast here.
            guard !isSkeinStarted else {
                return
            }

            try startSkein(validating: [
                DependencyProbe(AppConfiguration.self),
                DependencyProbe(AccountScreenModel.self)
            ]) {
                modules(applicationModule)
            }
            defer { stopSkein() }

            let screenModel: AccountScreenModel = try mainActorGet()
            print("Validated main-actor screen model for \(screenModel.apiBaseURL)")
        } catch {
            print("Application startup validation failed: \(error)")
        }
    }
}
