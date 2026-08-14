/// The source location at which a Skein declaration was made.
public struct SkeinSourceLocation: Equatable, Hashable, Sendable {
    public let fileID: String
    public let line: UInt

    public init(fileID: String, line: UInt) {
        self.fileID = fileID
        self.line = line
    }
}

/// One dependency in a resolution trace.
public struct SkeinResolutionFrame: Equatable, Sendable {
    public let type: String
    public let qualifier: String?
    public let argumentType: String?
    public let registration: SkeinSourceLocation?

    public init(
        type: String,
        qualifier: String?,
        argumentType: String?,
        registration: SkeinSourceLocation?
    ) {
        self.type = type
        self.qualifier = qualifier
        self.argumentType = argumentType
        self.registration = registration
    }
}

/// A resolution failure augmented with the complete root-to-failure trace.
///
/// Provider errors are retained verbatim in ``underlying`` so callers can
/// continue to inspect or cast their domain-specific error.
public struct SkeinResolutionError: Error, @unchecked Sendable {
    public let underlying: any Error
    public let path: [SkeinResolutionFrame]

    public init(underlying: any Error, path: [SkeinResolutionFrame]) {
        self.underlying = underlying
        self.path = path
    }
}

/// A module configuration failure with source locations for both declarations.
public struct SkeinConfigurationError: Error, @unchecked Sendable {
    public let underlying: SkeinError
    public let firstRegistration: SkeinSourceLocation
    public let duplicateRegistration: SkeinSourceLocation

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
