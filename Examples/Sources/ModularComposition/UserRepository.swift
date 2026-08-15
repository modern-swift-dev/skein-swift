final class UserRepository {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func currentUserName() -> String {
        client.fetchUserName()
    }
}
