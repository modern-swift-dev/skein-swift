/// Tracks containers and scopes currently performing disposal in a task.
package enum DisposalContext {
    /// The identities of disposal owners active in the current task.
    @TaskLocal package static var owners: Set<ObjectIdentifier> = []
}
