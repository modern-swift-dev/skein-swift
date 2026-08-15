#if os(macOS) || os(Linux)
import Skein
import Vapor

struct SkeinRequestScopeStorageKey: StorageKey {
    typealias Value = SkeinScopeInstance<VaporRequestScope>
}
#endif
