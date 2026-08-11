import Foundation

package final class Container: Resolver, @unchecked Sendable {
    private static let resolutionStackKey = "Koin.ResolutionStack"

    private let lock = NSRecursiveLock()
    private let bindings: [BindingKey: Binding]
    private var singletons: [BindingKey: Any] = [:]

    package init(modules: [Module]) throws {
        var collected: [BindingKey: Binding] = [:]
        for module in modules {
            for binding in module.bindings {
                guard collected[binding.key] == nil else {
                    throw KoinError.duplicateBinding(
                        type: binding.key.typeName,
                        qualifier: binding.key.qualifier?.description
                    )
                }
                collected[binding.key] = binding
            }
        }
        bindings = collected
    }

    package func get<Service>(_ type: Service.Type, qualifier: (any KoinQualifier)?) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier)
        lock.lock()
        defer { lock.unlock() }

        let binding = try binding(for: key)
        guard case let .standard(provider) = binding.provider else {
            throw KoinError.mainActorBindingRequiresMainActor(
                type: key.typeName,
                qualifier: key.qualifier?.description
            )
        }
        if binding.lifetime == .single, let instance = singletons[key] {
            return try cast(instance, to: type)
        }

        let instance = try withResolution(of: key) {
            try provider(self)
        }
        let resolved: Service = try cast(instance, to: type)
        if binding.lifetime == .single {
            singletons[key] = resolved
        }
        return resolved
    }

    @MainActor
    package func mainActorGet<Service>(
        _ type: Service.Type,
        qualifier: (any KoinQualifier)?
    ) throws -> Service {
        let key = BindingKey(type, qualifier: qualifier)
        lock.lock()
        defer { lock.unlock() }

        let binding = try binding(for: key)
        if binding.lifetime == .single, let instance = singletons[key] {
            return try cast(instance, to: type)
        }

        let instance: Any
        switch binding.provider {
        case let .standard(provider):
            instance = try withResolution(of: key) {
                try provider(self)
            }
        case let .mainActor(provider):
            instance = try withResolution(of: key) {
                try provider(self)
            }
        }
        let resolved: Service = try cast(instance, to: type)
        if binding.lifetime == .single {
            singletons[key] = resolved
        }
        return resolved
    }

    private func binding(for key: BindingKey) throws -> Binding {
        guard let binding = bindings[key] else {
            throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
        }
        return binding
    }

    private func withResolution<Result>(
        of key: BindingKey,
        _ resolve: () throws -> Result
    ) throws -> Result {
        let stack = resolutionStack()
        if let cycleStart = stack.keys.firstIndex(of: key) {
            let path = Array(stack.keys[cycleStart...]) + [key]
            throw KoinError.circularDependency(path: path.map(\.description))
        }

        stack.keys.append(key)
        defer { _ = stack.keys.popLast() }
        return try resolve()
    }

    private func resolutionStack() -> ResolutionStack {
        let dictionary = Thread.current.threadDictionary
        if let stack = dictionary[Self.resolutionStackKey] as? ResolutionStack {
            return stack
        }
        let stack = ResolutionStack()
        dictionary[Self.resolutionStackKey] = stack
        return stack
    }

    private func cast<Service>(_ value: Any, to type: Service.Type) throws -> Service {
        guard let resolved = value as? Service else {
            throw KoinError.resolvedTypeMismatch(
                expected: String(reflecting: type),
                actual: String(reflecting: Swift.type(of: value))
            )
        }
        return resolved
    }
}
