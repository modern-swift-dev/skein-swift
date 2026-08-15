#if os(macOS) || os(Linux)
import Skein
import Vapor

struct SkeinApplicationStorageKey: StorageKey {
    typealias Value = SkeinApplication
}
#endif
