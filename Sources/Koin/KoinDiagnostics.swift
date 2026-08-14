/// The source location at which a Koin declaration was made.
public struct KoinSourceLocation: Equatable, Hashable, Sendable {
    public let fileID: String
    public let line: UInt

    public init(fileID: String, line: UInt) {
        self.fileID = fileID
        self.line = line
    }
}

/// One dependency in a resolution trace.
public struct KoinResolutionFrame: Equatable, Sendable {
    public let type: String
    public let qualifier: String?
    public let argumentType: String?
    public let registration: KoinSourceLocation?

    public init(
        type: String,
        qualifier: String?,
        argumentType: String?,
        registration: KoinSourceLocation?
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
public struct KoinResolutionError: Error, @unchecked Sendable {
    public let underlying: any Error
    public let path: [KoinResolutionFrame]

    public init(underlying: any Error, path: [KoinResolutionFrame]) {
        self.underlying = underlying
        self.path = path
    }
}

/// A module configuration failure with source locations for both declarations.
public struct KoinConfigurationError: Error, @unchecked Sendable {
    public let underlying: KoinError
    public let firstRegistration: KoinSourceLocation
    public let duplicateRegistration: KoinSourceLocation

    public init(
        underlying: KoinError,
        firstRegistration: KoinSourceLocation,
        duplicateRegistration: KoinSourceLocation
    ) {
        self.underlying = underlying
        self.firstRegistration = firstRegistration
        self.duplicateRegistration = duplicateRegistration
    }
}
