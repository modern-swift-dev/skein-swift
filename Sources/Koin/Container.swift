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

        guard let binding = bindings[key] else {
            throw KoinError.missingBinding(type: key.typeName, qualifier: key.qualifier?.description)
        }
        if binding.lifetime == .single, let instance = singletons[key] {
            return try cast(instance, to: type)
        }

        let stack = resolutionStack()
        if let cycleStart = stack.keys.firstIndex(of: key) {
            let path = Array(stack.keys[cycleStart...]) + [key]
            throw KoinError.circularDependency(path: path.map(\.description))
        }

        stack.keys.append(key)
        defer { _ = stack.keys.popLast() }
        let instance = try binding.provider(self)
        let resolved: Service = try cast(instance, to: type)
        if binding.lifetime == .single {
            singletons[key] = resolved
        }
        return resolved
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
