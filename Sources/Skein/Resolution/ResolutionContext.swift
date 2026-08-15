/// Stores the dependency-resolution trace associated with a task.
package enum ResolutionContext {
    /// The ordered resolution entries active in the current task.
    @TaskLocal package static var entries: [ResolutionTraceEntry] = []
}
