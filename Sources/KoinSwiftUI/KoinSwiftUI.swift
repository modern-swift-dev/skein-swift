#if canImport(SwiftUI)
import Koin
import SwiftUI

/// Errors produced by the SwiftUI integration layer.
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public enum KoinSwiftUIError: Error, Equatable, LocalizedError {
    /// No application was supplied by a surrounding `koinApplication(_:)` modifier.
    case missingApplication

    public var errorDescription: String? {
        switch self {
            case .missingApplication:
                "No KoinApplication is present in the SwiftUI environment. Apply .koinApplication(_:) to an ancestor view."
        }
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct KoinApplicationEnvironmentKey: EnvironmentKey {
    static let defaultValue: KoinApplication? = nil
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public extension EnvironmentValues {
    /// The nearest Koin application supplied to the view hierarchy, if any.
    var koinApplication: KoinApplication? {
        get { self[KoinApplicationEnvironmentKey.self] }
        set { self[KoinApplicationEnvironmentKey.self] = newValue }
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public extension View {
    /// Makes an application available to this view and its descendants.
    ///
    /// Nested modifiers use SwiftUI's normal nearest-value-wins behavior.
    func koinApplication(_ application: KoinApplication) -> some View {
        environment(\.koinApplication, application)
    }
}

/// Resolves and retains an observable object from the nearest Koin application.
///
/// The resolution result is retained for the lifetime of this property's SwiftUI
/// identity. To resolve again with a new application or argument value, give the
/// enclosing view a new identity with `.id(...)`.
@MainActor
@propertyWrapper
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) public struct KoinStateObject<Model: ObservableObject>: @preconcurrency DynamicProperty {
    @Environment(\.koinApplication) private var application
    @StateObject private var storage: Storage<Model>

    private let configuration: Configuration
    private let resolve: (KoinApplication) throws -> Model

    /// Resolves an ordinary Koin binding.
    public init(qualifier: (any KoinQualifier)? = nil) {
        configuration = Configuration(
            qualifier: qualifier.map(QualifierSnapshot.init),
            argumentsDescription: nil,
            argumentsType: nil
        )
        resolve = { application in
            try application.mainActorGet(Model.self, qualifier: qualifier)
        }
        _storage = StateObject(wrappedValue: Storage())
    }

    /// Resolves a typed assisted-factory binding.
    public init<Arguments>(
        arguments: Arguments,
        qualifier: (any KoinQualifier)? = nil
    ) {
        configuration = Configuration(
            qualifier: qualifier.map(QualifierSnapshot.init),
            argumentsDescription: String(reflecting: arguments),
            argumentsType: ObjectIdentifier(Arguments.self)
        )
        resolve = { application in
            try application.mainActorGet(Model.self, arguments: arguments, qualifier: qualifier)
        }
        _storage = StateObject(wrappedValue: Storage())
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
            application: application,
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
@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private final class Storage<Model: ObservableObject>: ObservableObject {
    private(set) var result: Result<Model, Error>?
    private var initialApplication: ObjectIdentifier?
    private var initialConfiguration: Configuration?

    func resolveIfNeeded(
        application: KoinApplication?,
        configuration: Configuration,
        resolve: (KoinApplication) throws -> Model
    ) {
        if result != nil {
            diagnoseChangedInputs(application: application, configuration: configuration)
            return
        }

        initialApplication = application.map(ObjectIdentifier.init)
        initialConfiguration = configuration
        guard let application else {
            result = .failure(KoinSwiftUIError.missingApplication)
            return
        }
        result = Result { try resolve(application) }
    }

    private func diagnoseChangedInputs(application: KoinApplication?, configuration: Configuration) {
        guard initialApplication != application.map(ObjectIdentifier.init) || initialConfiguration != configuration else {
            return
        }
        #if DEBUG
        debugPrint("KoinStateObject retained its original resolution because its Koin application or arguments changed. Use .id(...) to replace it.")
        #endif
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct Configuration: Equatable {
    let qualifier: QualifierSnapshot?
    let argumentsDescription: String?
    let argumentsType: ObjectIdentifier?

}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct QualifierSnapshot: Equatable {
    let type: ObjectIdentifier
    let value: String

    init(_ qualifier: any KoinQualifier) {
        type = ObjectIdentifier(Swift.type(of: qualifier))
        value = String(reflecting: qualifier)
    }
}
#endif
