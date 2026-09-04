#if os(macOS) || os(Linux)
import Skein
import Vapor

struct SkeinApplicationStorageKey: StorageKey {
    enum Value: Sendable {
        case initializing
        case initialized(SkeinApplication)
    }
}
#endif
