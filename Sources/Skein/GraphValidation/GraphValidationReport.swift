/// The result of successfully validating every declared root.
public struct GraphValidationReport: Equatable, Sendable {
    /// Bindings whose provider closures prevent structural validation from continuing.
    public let opaqueBindings: [OpaqueBinding]

    /// Creates a successful validation report.
    ///
    /// - Parameter opaqueBindings: Bindings whose dependencies could not be inspected structurally.
    public init(opaqueBindings: [OpaqueBinding]) {
        self.opaqueBindings = opaqueBindings
    }
}
