actor LifecycleTestGate {
    private var isOpen = false
    private var arrivals = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        arrivals += 1
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    func waitForArrivals(_ expected: Int) async {
        while arrivals < expected {
            await Task.yield()
        }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}
