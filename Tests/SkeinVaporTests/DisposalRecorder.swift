#if os(macOS) || os(Linux)
import Foundation

actor DisposalRecorder {
    private var values: [UUID] = []

    func append(_ value: UUID) {
        values.append(value)
    }

    func snapshot() -> [UUID] {
        values
    }
}
#endif
