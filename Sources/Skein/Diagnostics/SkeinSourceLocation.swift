/// The source location at which a Skein declaration was made.
public struct SkeinSourceLocation: Equatable, Hashable, Sendable {
    /// The compiler-provided identifier of the source file.
    public let fileID: String
    /// The one-based line number within ``fileID``.
    public let line: UInt

    /// Creates a source location.
    ///
    /// - Parameters:
    ///   - fileID: The compiler-provided identifier of the source file.
    ///   - line: The one-based line number within the file.
    public init(fileID: String, line: UInt) {
        self.fileID = fileID
        self.line = line
    }
}
