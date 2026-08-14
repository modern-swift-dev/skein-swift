import Foundation

package final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    package var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    package func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
