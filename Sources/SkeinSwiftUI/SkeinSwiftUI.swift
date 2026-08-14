#if canImport(SwiftUI)
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
    private let resolve: (SkeinApplication) throws -> Model

    /// Resolves an ordinary Skein binding.
    public init(qualifier: (any SkeinQualifier)? = nil) {
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
        qualifier: (any SkeinQualifier)? = nil
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
        result = Result { try resolve(application) }
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
    let qualifier: QualifierSnapshot?
    let argumentsDescription: String?
    let argumentsType: ObjectIdentifier?

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
