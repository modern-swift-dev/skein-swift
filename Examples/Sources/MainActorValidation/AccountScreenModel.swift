@MainActor final class AccountScreenModel {
    let apiBaseURL: String

    init(configuration: AppConfiguration) {
        apiBaseURL = configuration.apiBaseURL
    }
}
