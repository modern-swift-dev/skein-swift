#if canImport(SwiftUI)
import Combine
import Skein
import SwiftUI

/// Errors produced by the SwiftUI integration layer.
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public enum SkeinSwiftUIError: Error, Equatable, LocalizedError {
    /// No application was supplied by a surrounding `skeinApplication(_:)` modifier.
    case missingApplication

    public var errorDescription: String? {
        switch self {
            case .missingApplication:
                "No SkeinApplication is present in the SwiftUI environment. Apply .skeinApplication(_:) to an ancestor view."
        }
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct SkeinApplicationEnvironmentKey: EnvironmentKey {
    static let defaultValue: SkeinApplication? = nil
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public extension EnvironmentValues {
    /// The nearest Skein application supplied to the view hierarchy, if any.
    var skeinApplication: SkeinApplication? {
        get { self[SkeinApplicationEnvironmentKey.self] }
        set { self[SkeinApplicationEnvironmentKey.self] = newValue }
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public extension View {
    /// Makes an application available to this view and its descendants.
    ///
    /// Nested modifiers use SwiftUI's normal nearest-value-wins behavior.
    func skeinApplication(_ application: SkeinApplication) -> some View {
        environment(\.skeinApplication, application)
    }
}

/// Resolves and retains an observable object from the nearest Skein application.
///
/// The resolution result is retained for the lifetime of this property's SwiftUI
/// identity. To resolve again with a new application or argument value, give the
/// enclosing view a new identity with `.id(...)`.
@MainActor
@propertyWrapper
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public struct SkeinStateObject<Model: ObservableObject>: @preconcurrency DynamicProperty {
    @Environment(\.skeinApplication) private var application
    @StateObject private var storage: Storage<Model>

    private let configuration: Configuration
    private let usesApplication: Bool
    private let resolve: (SkeinApplication) throws -> Model

    /// Resolves an ordinary Skein binding.
    private init(resolving qualifier: (any SkeinQualifier)?) {
        configuration = Configuration(
            source: .resolution,
            qualifier: qualifier.map(QualifierSnapshot.init),
            argumentsDescription: nil,
            argumentsType: nil
        )
        usesApplication = true
        resolve = { application in
            try application.get(Model.self, qualifier: qualifier)
        }
        _storage = StateObject(wrappedValue: Storage())
    }

    /// Resolves a typed assisted-factory binding.
    private init<Arguments>(
        resolving arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) {
        configuration = Configuration(
            source: .resolution,
            qualifier: qualifier.map(QualifierSnapshot.init),
            argumentsDescription: String(reflecting: arguments),
            argumentsType: ObjectIdentifier(Arguments.self)
        )
        usesApplication = true
        resolve = { application in
            try application.get(Model.self, arguments: arguments, qualifier: qualifier)
        }
        _storage = StateObject(wrappedValue: Storage())
    }

    private init(instance model: Model) {
        let configuration = Configuration(
            source: .instance(ObjectIdentifier(model)),
            qualifier: nil,
            argumentsDescription: nil,
            argumentsType: nil
        )
        self.configuration = configuration
        usesApplication = false
        resolve = { _ in model }
        _storage = StateObject(
            wrappedValue: Storage(result: .success(model), configuration: configuration)
        )
    }

    /// Resolves an ordinary binding from the surrounding Skein application.
    public static func resolving(
        qualifier: (any SkeinQualifier)? = nil
    ) -> Self {
        Self(resolving: qualifier)
    }

    /// Resolves an assisted binding from the surrounding Skein application.
    public static func resolving<Arguments>(
        arguments: Arguments,
        qualifier: (any SkeinQualifier)? = nil
    ) -> Self {
        Self(resolving: arguments, qualifier: qualifier)
    }

    /// Retains an explicitly supplied model without consulting the environment.
    public static func instance(_ model: Model) -> Self {
        Self(instance: model)
    }

    public var wrappedValue: Model? {
        storage.result?.success
    }

    /// The retained resolution result, including resolution failures.
    public var projectedValue: Result<Model, Error>? {
        storage.result
    }

    public mutating func update() {
        storage.resolveIfNeeded(
            application: usesApplication ? application : nil,
            configuration: configuration,
            resolve: resolve
        )
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private extension Result where Failure == Error {
    var success: Success? {
        guard case let .success(value) = self else {
            return nil
        }
        return value
    }
}

@MainActor
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private final class Storage<Model: ObservableObject>: @preconcurrency ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private(set) var result: Result<Model, Error>?
    private var initialApplication: ObjectIdentifier?
    private var initialConfiguration: Configuration?
    private var modelObservation: AnyCancellable?

    init(
        result: Result<Model, Error>? = nil,
        configuration: Configuration? = nil
    ) {
        self.result = result
        initialConfiguration = configuration
        if case let .success(model)? = result {
            observe(model)
        }
    }

    func resolveIfNeeded(
        application: SkeinApplication?,
        configuration: Configuration,
        resolve: (SkeinApplication) throws -> Model
    ) {
        if result != nil {
            diagnoseChangedInputs(application: application, configuration: configuration)
            return
        }

        initialApplication = application.map(ObjectIdentifier.init)
        initialConfiguration = configuration
        guard let application else {
            result = .failure(SkeinSwiftUIError.missingApplication)
            return
        }
        let result = Result { try resolve(application) }
        self.result = result
        if case let .success(model) = result {
            observe(model)
        }
    }

    private func observe(_ model: Model) {
        modelObservation = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    private func diagnoseChangedInputs(application: SkeinApplication?, configuration: Configuration) {
        guard initialApplication != application.map(ObjectIdentifier.init) || initialConfiguration != configuration else {
            return
        }
        #if DEBUG
        debugPrint("SkeinStateObject retained its original resolution because its Skein application or arguments changed. Use .id(...) to replace it.")
        #endif
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct Configuration: Equatable {
    let source: Source
    let qualifier: QualifierSnapshot?
    let argumentsDescription: String?
    let argumentsType: ObjectIdentifier?

}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private enum Source: Equatable {
    case resolution
    case instance(ObjectIdentifier)
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct QualifierSnapshot: Equatable {
    let type: ObjectIdentifier
    let value: String

    init(_ qualifier: any SkeinQualifier) {
        type = ObjectIdentifier(Swift.type(of: qualifier))
        value = String(reflecting: qualifier)
    }
}
#endif
