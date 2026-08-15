import Skein

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
