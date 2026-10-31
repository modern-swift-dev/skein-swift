#if canImport(SwiftUI)
    import Skein

    /// The inputs a resolving wrapper was configured with, captured for DEBUG diagnostics.
    ///
    /// In release builds the configuration is empty, so assisted arguments are never described.
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) struct ResolutionConfiguration: Equatable {
        #if DEBUG
            /// Where the wrapper's model comes from.
            enum Source: Equatable {
                case resolution
                case instance(ObjectIdentifier)
            }

            /// A comparable description of a qualifier.
            struct QualifierSnapshot: Equatable {
                let type: ObjectIdentifier
                let value: String

                init(_ qualifier: any SkeinQualifier) {
                    type = ObjectIdentifier(Swift.type(of: qualifier))
                    value = String(reflecting: qualifier)
                }
            }

            let source: Source
            let scope: ObjectIdentifier?
            let qualifier: QualifierSnapshot?
            let argumentsDescription: String?
            let argumentsType: ObjectIdentifier?
        #endif
    }
#endif
