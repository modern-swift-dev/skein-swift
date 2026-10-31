#if canImport(SwiftUI)
    import Observation
    import Skein
    import SwiftUI

    /// Resolves and retains an `@Observable` model from the nearest Skein application.
    ///
    /// `SkeinState` is to `@State` what ``SkeinStateObject`` is to `@StateObject`: use it for
    /// models built with the Observation framework. SwiftUI tracks the model's properties that the
    /// view reads, so the view re-renders when they change.
    ///
    /// ```swift
    /// @Observable @MainActor final class CounterModel { var count = 0 }
    ///
    /// struct CounterView: View {
    ///     @SkeinState<CounterModel> private var model: CounterModel?
    ///
    ///     init() { _model = .resolving() }
    ///
    ///     var body: some View {
    ///         if let model { Text("\(model.count)") }
    ///     }
    /// }
    /// ```
    ///
    /// The resolution result is retained for the lifetime of this property's SwiftUI identity. To
    /// resolve again with a new application or argument value, give the enclosing view a new
    /// identity with `.id(...)`. The only exception is ``SkeinSwiftUIError/missingApplication``:
    /// when an update runs before any application is in the environment, the property resolves
    /// again on the first later update that finds one. Successful results and provider failures
    /// stay retained, so a failing provider is not run again on every render.
    @MainActor
    @propertyWrapper
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) public struct SkeinState<Model: AnyObject & Observable>: @preconcurrency DynamicProperty {
        @Environment(\.skeinApplication) private var application
        @State private var state: ResolutionState<Model>
        private let request: ResolutionRequest<Model>

        private init(request: ResolutionRequest<Model>) {
            self.request = request
            _state = State(initialValue: ResolutionState(request: request, wrapperName: "SkeinState"))
        }

        /// Configures this property to resolve an ordinary binding from the surrounding Skein application.
        ///
        /// Resolution is deferred until SwiftUI updates the property. Inspect ``projectedValue``
        /// to observe either the resolved model or a resolution failure.
        ///
        /// - Parameter qualifier: An optional qualifier selecting a specific binding.
        /// - Returns: A property-wrapper value configured for deferred resolution.
        public static func resolving(qualifier: (any SkeinQualifier)? = nil) -> Self {
            Self(request: .plain(qualifier: qualifier))
        }

        /// Configures this property to resolve an assisted binding from the surrounding Skein application.
        ///
        /// Resolution is deferred until SwiftUI updates the property. Inspect ``projectedValue``
        /// to observe either the resolved model or a resolution failure.
        ///
        /// - Parameters:
        ///   - arguments: The assisted arguments passed to the registered provider.
        ///   - qualifier: An optional qualifier selecting a specific binding.
        /// - Returns: A property-wrapper value configured for deferred resolution.
        public static func resolving(arguments: some Any, qualifier: (any SkeinQualifier)? = nil) -> Self {
            Self(request: .assisted(arguments: arguments, qualifier: qualifier))
        }

        /// Retains an explicitly supplied model without consulting the environment.
        ///
        /// - Parameter model: The observable model to retain.
        /// - Returns: A property-wrapper value containing `model`.
        public static func instance(_ model: Model) -> Self {
            Self(request: .instance(model))
        }

        /// The retained model, or `nil` before resolution or after a resolution failure.
        public var wrappedValue: Model? {
            state.model
        }

        /// The retained resolution result, including failures, or `nil` before SwiftUI updates the property.
        public var projectedValue: Result<Model, Error>? {
            state.result
        }

        /// Performs the property's deferred resolution when SwiftUI updates it.
        ///
        /// The first result is retained for this property's SwiftUI identity. Later updates
        /// do not resolve again when the application, qualifier, or arguments change.
        /// A ``SkeinSwiftUIError/missingApplication`` failure is the exception: it is
        /// replaced by a new resolution once an application appears in the environment.
        public mutating func update() {
            state.resolveIfNeeded(application: application, request: request)
        }
    }
#endif
