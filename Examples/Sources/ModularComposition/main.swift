import Koin

protocol APIClient {
    func fetchUserName() -> String
}

final class LiveAPIClient: APIClient {
    func fetchUserName() -> String {
        "Taylor"
    }
}

final class UserRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func currentUserName() -> String {
        client.fetchUserName()
    }
}

final class ProfilePresenter {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func title() -> String {
        "Profile: \(repository.currentUserName())"
    }
}

let networkingModule = module {
    single((any APIClient).self) { _ in LiveAPIClient() }
}

let dataModule = module {
    single(UserRepository.self) { resolver in
        UserRepository(client: try resolver.get())
    }
}

let featureModule = module {
    factory(ProfilePresenter.self) { resolver in
        ProfilePresenter(repository: try resolver.get())
    }
}

do {
    try startKoin {
        modules(networkingModule, dataModule, featureModule)
    }
    defer { stopKoin() }

    let presenter: ProfilePresenter = try get()
    print(presenter.title())
} catch {
    print("Koin setup or resolution failed: \(error)")
}
