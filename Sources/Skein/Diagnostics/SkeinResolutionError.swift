/// A resolution failure augmented with the complete root-to-failure trace.
///
/// Provider errors are retained verbatim in ``underlying`` so callers can
/// continue to inspect or cast their domain-specific error.
public struct SkeinResolutionError: Error, @unchecked Sendable {
    /// The original provider or container error that caused resolution to fail.
    public let underlying: any Error
    /// The root-to-failure dependency path captured during resolution.
    public let path: [SkeinResolutionFrame]

    /// Creates a resolution error that preserves its cause and dependency path.
    ///
    /// - Parameters:
    ///   - underlying: The original provider or container error.
    ///   - path: The root-to-failure dependency path.
    public init(underlying: any Error, path: [SkeinResolutionFrame]) {
        self.underlying = underlying
        self.path = path
    }
}
