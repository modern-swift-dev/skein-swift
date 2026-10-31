import Foundation

/// Resumes a waiting continuation exactly once, with either the task's result or cancellation.
///
/// `@unchecked Sendable` is required because the cancellation handler and the forwarding
/// task race to resume the continuation from different threads. Every stored property is
/// guarded by `lock`, and the continuation is cleared before it is resumed, so it is resumed
/// at most once. `WaiterCancellationTests` exercises cancellation while a waiter is parked.
final class TaskResultResumption<Success: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Result<Success, Error>, Error>?
    private var isCancelled = false

    /// Stores the continuation, or resumes it with cancellation when the caller is already cancelled.
    ///
    /// - Parameter continuation: The continuation of the waiting caller.
    /// - Returns: `false` when the caller was already cancelled and the continuation was resumed.
    func install(_ continuation: CheckedContinuation<Result<Success, Error>, Error>) -> Bool {
        let cancelled = lock.withLock {
            if !isCancelled {
                self.continuation = continuation
            }
            return isCancelled
        }
        if cancelled {
            continuation.resume(throwing: CancellationError())
        }
        return !cancelled
    }

    /// Resumes the waiting caller with the task's result, unless it already stopped waiting.
    ///
    /// - Parameter result: The result of the awaited task.
    func resume(returning result: Result<Success, Error>) {
        take()?.resume(returning: result)
    }

    /// Resumes the waiting caller with `CancellationError`, unless it already received a result.
    func cancel() {
        let continuation = lock.withLock {
            isCancelled = true
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(throwing: CancellationError())
    }

    private func take() -> CheckedContinuation<Result<Success, Error>, Error>? {
        lock.withLock {
            defer { continuation = nil }
            return continuation
        }
    }
}
