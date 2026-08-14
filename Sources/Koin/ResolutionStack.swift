import Foundation

package final class ResolutionStacks: NSObject {
    package var keysByContext: [ObjectIdentifier: [BindingKey]] = [:]
    package var trace: [ResolutionTraceEntry] = []
}

package struct ResolutionTraceEntry {
    package let key: BindingKey
    package let source: KoinSourceLocation?
}
