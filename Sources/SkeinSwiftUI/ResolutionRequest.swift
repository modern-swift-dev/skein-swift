#if canImport(SwiftUI)
    import Skein

    /// Describes how a SwiftUI property wrapper obtains its model.
    ///
    /// Shared by ``SkeinStateObject`` and ``SkeinState`` so both follow the same resolution rules.
    @MainActor
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) struct ResolutionRequest<Model> {
        /// The configured inputs, compared in DEBUG builds to diagnose ignored changes.
        let configuration: ResolutionConfiguration
        /// Whether the model is resolved from the environment's application.
        let usesApplication: Bool
        /// Resolves the model from an application.
        let resolve: (SkeinApplication) throws -> Model
        /// The result available before any update, such as an explicitly supplied model.
        let initialResult: Result<Model, Error>?

        /// Resolves an ordinary binding.
        ///
        /// - Parameter qualifier: The qualifier selecting the binding, or `nil`.
        /// - Returns: A request that resolves from the environment's application.
        static func plain(qualifier: (any SkeinQualifier)?) -> Self {
            #if DEBUG
                let configuration = ResolutionConfiguration(
                    source: .resolution,
                    qualifier: qualifier.map(ResolutionConfiguration.QualifierSnapshot.init),
                    argumentsDescription: nil,
                    argumentsType: nil
                )
            #else
                let configuration = ResolutionConfiguration()
            #endif
            return Self(configuration: configuration, usesApplication: true, resolve: { application in
                try application.get(Model.self, qualifier: qualifier)
            }, initialResult: nil)
        }

        /// Resolves an assisted binding.
        ///
        /// - Parameters:
        ///   - arguments: The assisted arguments passed to the provider.
        ///   - qualifier: The qualifier selecting the binding, or `nil`.
        /// - Returns: A request that resolves from the environment's application.
        static func assisted<Arguments>(arguments: Arguments, qualifier: (any SkeinQualifier)?) -> Self {
            #if DEBUG
                let configuration = ResolutionConfiguration(
                    source: .resolution,
                    qualifier: qualifier.map(ResolutionConfiguration.QualifierSnapshot.init),
                    argumentsDescription: String(reflecting: arguments),
                    argumentsType: ObjectIdentifier(Arguments.self)
                )
            #else
                let configuration = ResolutionConfiguration()
            #endif
            return Self(configuration: configuration, usesApplication: true, resolve: { application in
                try application.get(Model.self, arguments: arguments, qualifier: qualifier)
            }, initialResult: nil)
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) extension ResolutionRequest where Model: AnyObject {
        /// Retains an explicitly supplied model without consulting the environment.
        ///
        /// - Parameter model: The model to retain.
        /// - Returns: A request whose result is already available.
        static func instance(_ model: Model) -> Self {
            #if DEBUG
                let configuration = ResolutionConfiguration(
                    source: .instance(ObjectIdentifier(model)),
                    qualifier: nil,
                    argumentsDescription: nil,
                    argumentsType: nil
                )
            #else
                let configuration = ResolutionConfiguration()
            #endif
            return Self(configuration: configuration, usesApplication: false, resolve: { _ in model }, initialResult: .success(model))
        }
    }
#endif
