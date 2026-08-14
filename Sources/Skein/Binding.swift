/// A dependency registration created by one of Skein's registration functions.
public struct Binding {
    package let key: BindingKey
    package let lifetime: BindingLifetime
    package let isolation: BindingIsolation
    package let provider: BindingProvider
    package let disposer: BindingDisposer?
    package let source: SkeinSourceLocation
    /// `nil` means opaque; an empty array means a known leaf.
    package let dependencies: [BindingDependency]?
    package let rootPolicy: RootPolicy?
    package let rootSource: SkeinSourceLocation?

    package init(
        key: BindingKey,
        lifetime: BindingLifetime,
        isolation: BindingIsolation,
        provider: BindingProvider,
        disposer: BindingDisposer? = nil,
        source: SkeinSourceLocation = .init(fileID: "<unknown>", line: 0),
        dependencies: [BindingDependency]? = nil,
        rootPolicy: RootPolicy? = nil,
        rootSource: SkeinSourceLocation? = nil
    ) {
        self.key = key
        self.lifetime = lifetime
        self.isolation = isolation
        self.provider = provider
        self.disposer = disposer
        self.source = source
        self.dependencies = dependencies
        self.rootPolicy = rootPolicy
        self.rootSource = rootSource
    }

    /// Declares this binding as a structural or eager application root.
    public func root(
        _ policy: RootPolicy = .structural,
        fileID: String = #fileID,
        line: UInt = #line
    ) -> Binding {
        Binding(key: key, lifetime: lifetime, isolation: isolation, provider: provider,
                disposer: disposer, source: source, dependencies: dependencies,
                rootPolicy: policy, rootSource: .init(fileID: fileID, line: line))
    }
}

/// Public, stable description of where a binding executes.
public enum BindingIsolationDescription: Equatable, Hashable, Sendable {
    case mainActor
    case nonisolated
    case customActor(String)
}

package enum BindingIsolation: Hashable, Sendable {
    case mainActor
    case nonisolated
    case customActor(id: ObjectIdentifier, name: String)

    package var description: BindingIsolationDescription {
        switch self {
            case .mainActor: .mainActor
            case .nonisolated: .nonisolated
            case let .customActor(_, name): .customActor(name)
        }
    }
}

package struct UncheckedProviderValue: @unchecked Sendable {
    package let value: Any
}

package struct ActorProviderStorage: Sendable {
    package let expectedActorID: ObjectIdentifier
    package let actualActorID: ObjectIdentifier?
    package let actorName: String
    package let invoke: @Sendable (any Resolver) async throws -> UncheckedProviderValue
}

package struct ActorAssistedProviderStorage: Sendable {
    package let expectedActorID: ObjectIdentifier
    package let actualActorID: ObjectIdentifier?
    package let actorName: String
    package let invoke: @Sendable (any Resolver, UncheckedProviderValue) async throws -> UncheckedProviderValue
}

package enum BindingProvider {
    case mainActor(@MainActor (any Resolver) throws -> Any)
    case mainActorAssisted(@MainActor (any Resolver, Any) throws -> Any)
    case nonisolated(@Sendable (any Resolver) throws -> Any)
    case nonisolatedAssisted(@Sendable (any Resolver, Any) throws -> Any)
    case customActor(ActorProviderStorage)
    case customActorAssisted(ActorAssistedProviderStorage)
}

package struct ActorDisposerStorage: Sendable {
    package let expectedActorID: ObjectIdentifier
    package let actualActorID: ObjectIdentifier?
    package let actorName: String
    package let invoke: @Sendable (UncheckedProviderValue) async -> Void
}

package enum BindingDisposer {
    case mainActor(@MainActor (UncheckedProviderValue) async -> Void)
    case nonisolated(@Sendable (UncheckedProviderValue) async -> Void)
    case customActor(ActorDisposerStorage)
}

package struct BindingDependency: Hashable, Sendable {
    package let key: BindingKey
    package init(_ type: (some Any).Type) { key = BindingKey(type, qualifier: nil) }
}
