#if os(macOS) || os(Linux)
    actor InitializationGate {
        private var entered = false
        private var arrival: CheckedContinuation<Void, Never>?
        private var release: CheckedContinuation<Void, Never>?

        func wait() async {
            entered = true
            arrival?.resume()
            arrival = nil
            await withCheckedContinuation { release = $0 }
        }

        func waitUntilEntered() async {
            guard !entered else {
                return
            }
            await withCheckedContinuation { arrival = $0 }
        }

        func open() {
            release?.resume()
            release = nil
        }
    }
#endif
