#if canImport(SwiftUI)
    import Combine
    import Skein
    import SwiftUI

    /// Errors produced by the SwiftUI integration layer.
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) public enum SkeinSwiftUIError: Error, Equatable, LocalizedError {
        /// No application was supplied by a surrounding `skeinApplication(_:)` modifier.
        ///
        /// Resolving wrappers retry this failure once an application appears.
        case missingApplication

        /// A wrapper resolving `in:` a scope kind has no surrounding `skeinScope(_:id:)` modifier of that kind.
        ///
        /// Resolving wrappers retry this failure once a scope of that kind appears.
        ///
        /// - Parameter scope: The fully qualified name of the scope kind.
        case missingScope(scope: String)

        /// Creating the view-owned scope of a surrounding `skeinScope(_:id:)` modifier failed.
        ///
        /// The failure is kept for the view's identity; give the owning view a new identity with
        /// `.id(...)` to try again.
        ///
        /// - Parameters:
        ///   - scope: The fully qualified name of the scope kind.
        ///   - underlying: The error thrown while creating the scope, such as
        ///     `SkeinError.missingBinding(type:qualifier:)` for a seed or `SkeinError.applicationClosed`.
        case scopeCreationFailed(scope: String, underlying: SkeinError)

        /// A localized description suitable for display and diagnostics.
        public var errorDescription: String? {
            switch self {
                case .missingApplication:
                    "No SkeinApplication is present in the SwiftUI environment. Apply .skeinApplication(_:) to an ancestor view."
                case let .missingScope(scope):
                    "No \(scope) scope is present in the SwiftUI environment. Apply .skeinScope(\(scope).self, id:) to an ancestor view."
                case let .scopeCreationFailed(scope, underlying):
                    "Creating the \(scope) scope for this view failed: \(underlying)"
            }
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct SkeinApplicationEnvironmentKey: EnvironmentKey {
        static let defaultValue: SkeinApplication? = nil
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) public extension EnvironmentValues {
        /// The nearest Skein application supplied to the view hierarchy, if any.
        var skeinApplication: SkeinApplication? {
            get { self[SkeinApplicationEnvironmentKey.self] }
            set { self[SkeinApplicationEnvironmentKey.self] = newValue }
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) public extension View {
        /// Makes an application available to this view and its descendants.
        ///
        /// Nested modifiers use SwiftUI's normal nearest-value-wins behavior.
        ///
        /// - Parameter application: The Skein application to place in the environment.
        /// - Returns: A view whose environment contains `application`.
        func skeinApplication(_ application: SkeinApplication) -> some View {
            environment(\.skeinApplication, application)
        }
    }

    /// Resolves and retains an observable object from the nearest Skein application.
    ///
    /// The resolution result is retained for the lifetime of this property's SwiftUI
    /// identity. To resolve again with a new application or argument value, give the
    /// enclosing view a new identity with `.id(...)`.
    ///
    /// The exceptions are ``SkeinSwiftUIError/missingApplication`` and
    /// ``SkeinSwiftUIError/missingScope(scope:)``: when an update runs before the application or
    /// view-owned scope is in the environment, the property resolves again on the first later
    /// update that finds it. Successful results, provider failures and
    /// ``SkeinSwiftUIError/scopeCreationFailed(scope:underlying:)`` stay retained, so a failing
    /// provider is not run again on every render.
    @MainActor
    @propertyWrapper
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) public struct SkeinStateObject<Model: ObservableObject>: @preconcurrency DynamicProperty {
        @Environment(\.skeinApplication) private var application
        @Environment(\.skeinScopes) private var scopes
        @StateObject private var storage: Storage<Model>
        private let request: ResolutionRequest<Model>

        private init(request: ResolutionRequest<Model>) {
            self.request = request
            _storage = StateObject(wrappedValue: Storage(request: request))
        }

        /// Configures this property to resolve an ordinary binding from the surrounding Skein application.
        ///
        /// Resolution is deferred until SwiftUI updates the property. Inspect ``projectedValue``
        /// to observe either the resolved model or a resolution failure.
        ///
        /// - Parameter qualifier: An optional qualifier selecting a specific binding.
        /// - Returns: A property-wrapper value configured for deferred resolution.
        public static func resolving(
            qualifier: (any SkeinQualifier)? = nil
        ) -> Self {
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
        public static func resolving(
            arguments: some Any,
            qualifier: (any SkeinQualifier)? = nil
        ) -> Self {
            Self(request: .assisted(arguments: arguments, qualifier: qualifier))
        }

        /// Configures this property to resolve an ordinary binding from the nearest view-owned scope of a kind.
        ///
        /// The scope is supplied by a surrounding `skeinScope(_:id:)` modifier. Scoped bindings of
        /// that kind resolve from the scope; other bindings resolve from its application. Without
        /// such a modifier the result is ``SkeinSwiftUIError/missingScope(scope:)``, which is
        /// retried once the scope appears.
        ///
        /// - Parameters:
        ///   - kind: The scope kind to resolve from.
        ///   - qualifier: An optional qualifier selecting a specific binding.
        /// - Returns: A property-wrapper value configured for deferred resolution.
        public static func resolving(in kind: (some SkeinScope).Type, qualifier: (any SkeinQualifier)? = nil) -> Self {
            Self(request: .inScope(kind, qualifier: qualifier))
        }

        /// Configures this property to resolve an assisted binding from the nearest view-owned scope of a kind.
        ///
        /// See ``resolving(in:qualifier:)`` for how the scope is found.
        ///
        /// - Parameters:
        ///   - kind: The scope kind to resolve from.
        ///   - arguments: The assisted arguments passed to the registered provider.
        ///   - qualifier: An optional qualifier selecting a specific binding.
        /// - Returns: A property-wrapper value configured for deferred resolution.
        public static func resolving(
            in kind: (some SkeinScope).Type,
            arguments: some Any,
            qualifier: (any SkeinQualifier)? = nil
        ) -> Self {
            Self(request: .inScope(kind, arguments: arguments, qualifier: qualifier))
        }

        /// Retains an explicitly supplied model without consulting the environment.
        ///
        /// - Parameter model: The observable object to retain.
        /// - Returns: A property-wrapper value containing `model`.
        public static func instance(_ model: Model) -> Self {
            Self(request: .instance(model))
        }

        /// The retained model, or `nil` before resolution or after a resolution failure.
        public var wrappedValue: Model? {
            storage.state.model
        }

        /// The retained resolution result, including failures, or `nil` before SwiftUI updates the property.
        public var projectedValue: Result<Model, Error>? {
            storage.state.result
        }

        /// Performs the property's deferred resolution when SwiftUI updates it.
        ///
        /// The first result is retained for this property's SwiftUI identity. Later updates
        /// do not resolve again when the application, qualifier, or arguments change.
        /// ``SkeinSwiftUIError/missingApplication`` and ``SkeinSwiftUIError/missingScope(scope:)``
        /// failures are the exception: they are replaced by a new resolution once the
        /// application or scope appears in the environment.
        public mutating func update() {
            storage.resolveIfNeeded(environment: WrapperEnvironment(application: application, scopes: scopes), request: request)
        }
    }

    /// Retains a ``SkeinStateObject`` resolution and forwards the model's changes to SwiftUI.
    @MainActor
    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private final class Storage<Model: ObservableObject>: @preconcurrency ObservableObject {
        let objectWillChange = ObservableObjectPublisher()
        let state: ResolutionState<Model>
        private var modelObservation: AnyCancellable?

        init(request: ResolutionRequest<Model>) {
            state = ResolutionState(request: request, wrapperName: "SkeinStateObject")
            if let model = state.model {
                observe(model)
            }
        }

        func resolveIfNeeded(environment: WrapperEnvironment, request: ResolutionRequest<Model>) {
            if let model = state.resolveIfNeeded(environment: environment, request: request) {
                observe(model)
            }
        }

        private func observe(_ model: Model) {
            // Forward synchronously on the main thread so SwiftUI sees the change
            // before the mutation, preserving transaction and animation context.
            // Models that publish from another thread are forwarded with a main-actor hop.
            modelObservation = model.objectWillChange.sink { @Sendable [weak self] _ in
                if Thread.isMainThread {
                    MainActor.assumeIsolated {
                        self?.objectWillChange.send()
                    }
                } else {
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated {
                            self?.objectWillChange.send()
                        }
                    }
                }
            }
        }
    }
#endif
