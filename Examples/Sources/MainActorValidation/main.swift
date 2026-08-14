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
    instance(AppConfiguration())
    single(AccountScreenModel.self, using: AccountScreenModel.init)
        .root(.eager)
}

@main
@MainActor private struct MainActorValidation {
    static func main() async {
        do {
            // The application owns this policy and may log or fail fast here.
            try await startSkein(validation: .declaredRoots) {
                applicationModule
            }
            defer { stopSkein() }

            let screenModel: AccountScreenModel = try get()
            print("Validated main-actor screen model for \(screenModel.apiBaseURL)")
        } catch {
            print("Application startup validation failed: \(error)")
        }
    }
}
