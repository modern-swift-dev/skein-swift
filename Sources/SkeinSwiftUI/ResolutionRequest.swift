#if canImport(SwiftUI)
    import Skein

    /// Describes how a SwiftUI property wrapper obtains its model.
    ///
    /// Shared by ``SkeinStateObject`` and ``SkeinState`` so both follow the same resolution rules.
    @MainActor
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) struct ResolutionRequest<Model> {
        /// The configured inputs, compared in DEBUG builds to diagnose ignored changes.
        let configuration: ResolutionConfiguration
        /// Whether the model is resolved from the SwiftUI environment.
        let usesEnvironment: Bool
        /// Resolves the model from the wrapper's environment.
        let resolve: (WrapperEnvironment) throws -> Model
        /// The result available before any update, such as an explicitly supplied model.
        let initialResult: Result<Model, Error>?

        /// Resolves an ordinary binding from the environment's application.
        ///
        /// - Parameter qualifier: The qualifier selecting the binding, or `nil`.
        /// - Returns: A request that resolves from the environment.
        static func plain(qualifier: (any SkeinQualifier)?) -> Self {
            Self(configuration: configuration(scope: nil, qualifier: qualifier), usesEnvironment: true, resolve: { environment in
                try environment.requireApplication().get(Model.self, qualifier: qualifier)
            }, initialResult: nil)
        }

        /// Resolves an assisted binding from the environment's application.
        ///
        /// - Parameters:
        ///   - arguments: The assisted arguments passed to the provider.
        ///   - qualifier: The qualifier selecting the binding, or `nil`.
        /// - Returns: A request that resolves from the environment.
        static func assisted(arguments: some Any, qualifier: (any SkeinQualifier)?) -> Self {
            Self(configuration: configuration(scope: nil, qualifier: qualifier, arguments: arguments), usesEnvironment: true, resolve: { environment in
                try environment.requireApplication().get(Model.self, arguments: arguments, qualifier: qualifier)
            }, initialResult: nil)
        }

        /// Resolves an ordinary binding from the nearest view-owned scope of `kind`.
        ///
        /// - Parameters:
        ///   - kind: The scope kind to resolve from.
        ///   - qualifier: The qualifier selecting the binding, or `nil`.
        /// - Returns: A request that resolves from the environment.
        static func inScope(_ kind: (some SkeinScope).Type, qualifier: (any SkeinQualifier)?) -> Self {
            Self(configuration: configuration(scope: kind, qualifier: qualifier), usesEnvironment: true, resolve: { environment in
                try environment.scopes.scope(kind).get(Model.self, qualifier: qualifier)
            }, initialResult: nil)
        }

        /// Resolves an assisted binding from the nearest view-owned scope of `kind`.
        ///
        /// - Parameters:
        ///   - kind: The scope kind to resolve from.
        ///   - arguments: The assisted arguments passed to the provider.
        ///   - qualifier: The qualifier selecting the binding, or `nil`.
        /// - Returns: A request that resolves from the environment.
        static func inScope(
            _ kind: (some SkeinScope).Type,
            arguments: some Any,
            qualifier: (any SkeinQualifier)?
        ) -> Self {
            Self(configuration: configuration(scope: kind, qualifier: qualifier, arguments: arguments), usesEnvironment: true, resolve: { environment in
                try environment.scopes.scope(kind).get(Model.self, arguments: arguments, qualifier: qualifier)
            }, initialResult: nil)
        }

        private static func configuration(
            scope: (any SkeinScope.Type)?,
            qualifier: (any SkeinQualifier)?
        ) -> ResolutionConfiguration {
            #if DEBUG
                ResolutionConfiguration(
                    source: .resolution,
                    scope: scope.map { ObjectIdentifier($0) },
                    qualifier: qualifier.map(ResolutionConfiguration.QualifierSnapshot.init),
                    argumentsDescription: nil,
                    argumentsType: nil
                )
            #else
                ResolutionConfiguration()
            #endif
        }

        private static func configuration<Arguments>(
            scope: (any SkeinScope.Type)?,
            qualifier: (any SkeinQualifier)?,
            arguments: Arguments
        ) -> ResolutionConfiguration {
            #if DEBUG
                ResolutionConfiguration(
                    source: .resolution,
                    scope: scope.map { ObjectIdentifier($0) },
                    qualifier: qualifier.map(ResolutionConfiguration.QualifierSnapshot.init),
                    argumentsDescription: String(reflecting: arguments),
                    argumentsType: ObjectIdentifier(Arguments.self)
                )
            #else
                ResolutionConfiguration()
            #endif
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
                    scope: nil,
                    qualifier: nil,
                    argumentsDescription: nil,
                    argumentsType: nil
                )
            #else
                let configuration = ResolutionConfiguration()
            #endif
            return Self(configuration: configuration, usesEnvironment: false, resolve: { _ in model }, initialResult: .success(model))
        }
    }
#endif
