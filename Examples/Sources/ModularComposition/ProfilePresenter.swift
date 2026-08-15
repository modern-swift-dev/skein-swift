final class ProfilePresenter {
    private let repository: UserRepository

    init(repository: UserRepository) {
        self.repository = repository
    }

    func title() -> String {
        "Profile: \(repository.currentUserName())"
    }
}
