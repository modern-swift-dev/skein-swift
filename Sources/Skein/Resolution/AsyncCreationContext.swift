/// Stores the asynchronous creation currently executing in a task.
package enum AsyncCreationContext {
    /// The identity of the asynchronous creation executing in the current task, if any.
    @TaskLocal package static var current: AsyncCreationIdentity?
}
