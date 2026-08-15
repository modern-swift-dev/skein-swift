/// A module configuration failure with source locations for both declarations.
public struct SkeinConfigurationError: Error, @unchecked Sendable {
    /// The configuration error reported by the container.
    public let underlying: SkeinError
    /// The source location of the first conflicting registration.
    public let firstRegistration: SkeinSourceLocation
    /// The source location of the duplicate registration.
    public let duplicateRegistration: SkeinSourceLocation

    /// Creates a configuration error for two conflicting registrations.
    ///
    /// - Parameters:
    ///   - underlying: The configuration error reported by the container.
    ///   - firstRegistration: The source location of the first registration.
    ///   - duplicateRegistration: The source location of the duplicate registration.
    public init(
        underlying: SkeinError,
        firstRegistration: SkeinSourceLocation,
        duplicateRegistration: SkeinSourceLocation
    ) {
        self.underlying = underlying
        self.firstRegistration = firstRegistration
        self.duplicateRegistration = duplicateRegistration
    }
}
