import Skein

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
    single((any APIClient).self, provider: { _ in LiveAPIClient() })
}

let dataModule = module {
    single(UserRepository.self, using: UserRepository.init)
}

let featureModule = module {
    factory(ProfilePresenter.self, using: ProfilePresenter.init)
}

do {
    try startSkein {
        networkingModule
        dataModule
        featureModule
    }
    defer { stopSkein() }

    let presenter: ProfilePresenter = try get()
    print(presenter.title())
} catch {
    print("Skein setup or resolution failed: \(error)")
}
