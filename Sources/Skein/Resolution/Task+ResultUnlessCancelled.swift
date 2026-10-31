import Foundation

extension Task where Failure == Error {
    /// Awaits this task's result, but stops waiting as soon as the calling task is cancelled.
    ///
    /// `Task.value` keeps waiting after the awaiting task is cancelled. This method instead
    /// throws `CancellationError` immediately. Cancelling the caller does not cancel this
    /// task, so other waiters still receive its result.
    ///
    /// - Returns: The task's result, including any error the task threw.
    /// - Throws: `CancellationError` when the calling task is cancelled before this task finishes.
    func resultUnlessCancelled() async throws -> Result<Success, Error> {
        let resumption = TaskResultResumption<Success>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard resumption.install(continuation) else {
                    return
                }
                Task<Void, Never> {
                    await resumption.resume(returning: result)
                }
            }
        } onCancel: {
            resumption.cancel()
        }
    }
}
