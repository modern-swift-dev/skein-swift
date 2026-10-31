#if canImport(SwiftUI)
    import Skein

    /// The retained resolution result of a SwiftUI property wrapper, shared by
    /// ``SkeinStateObject`` and ``SkeinState``.
    ///
    /// The first result is kept for the wrapper's SwiftUI identity. The exceptions are the
    /// "not there yet" failures, ``SkeinSwiftUIError/missingApplication`` and
    /// ``SkeinSwiftUIError/missingScope(scope:)``, which are retried on every update until the
    /// application or scope appears. Successful results, provider failures and
    /// ``SkeinSwiftUIError/scopeCreationFailed(scope:underlying:)`` are never retried.
    @MainActor
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) final class ResolutionState<Model> {
        /// The retained result, or `nil` before the first update.
        private(set) var result: Result<Model, Error>?
        private let wrapperName: String
        #if DEBUG
            private var initialApplication: ObjectIdentifier?
            private var initialConfiguration: ResolutionConfiguration
        #endif

        /// The retained model, or `nil` before resolution or after a failure.
        var model: Model? {
            guard case let .success(model)? = result else {
                return nil
            }
            return model
        }

        /// Creates the state for a wrapper.
        ///
        /// - Parameters:
        ///   - request: The wrapper's request; its initial result is retained immediately.
        ///   - wrapperName: The wrapper's type name, used in DEBUG diagnostics.
        init(request: ResolutionRequest<Model>, wrapperName: String) {
            result = request.initialResult
            self.wrapperName = wrapperName
            #if DEBUG
                initialConfiguration = request.configuration
            #endif
        }

        /// Resolves the model when no result is retained yet, or when the retained result is a
        /// retryable "not there yet" failure.
        ///
        /// - Parameters:
        ///   - environment: What the wrapper finds in its SwiftUI environment.
        ///   - request: The wrapper's current request.
        /// - Returns: The newly resolved model, or `nil` when nothing new was resolved.
        @discardableResult
        func resolveIfNeeded(environment: WrapperEnvironment, request: ResolutionRequest<Model>) -> Model? {
            let application = request.usesEnvironment ? environment.application : nil
            if let result, !isRetryable(result) {
                #if DEBUG
                    diagnoseChangedInputs(application: application, configuration: request.configuration)
                #endif
                return nil
            }
            guard request.usesEnvironment else {
                return nil
            }

            #if DEBUG
                initialApplication = application.map(ObjectIdentifier.init)
                initialConfiguration = request.configuration
            #endif
            result = Result { try request.resolve(environment) }
            return model
        }

        private func isRetryable(_ result: Result<Model, Error>) -> Bool {
            guard case let .failure(error) = result else {
                return false
            }
            switch error as? SkeinSwiftUIError {
                case .missingApplication,
                     .missingScope: return true
                case .scopeCreationFailed,
                     nil: return false
            }
        }

        #if DEBUG
            private func diagnoseChangedInputs(application: SkeinApplication?, configuration: ResolutionConfiguration) {
                guard initialApplication != application.map(ObjectIdentifier.init) || initialConfiguration != configuration else {
                    return
                }
                debugPrint("\(wrapperName) retained its original resolution because its Skein application or arguments changed. Use .id(...) to replace it.")
            }
        #endif
    }
#endif
