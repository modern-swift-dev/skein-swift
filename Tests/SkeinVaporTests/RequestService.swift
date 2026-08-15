#if os(macOS) || os(Linux)
import Foundation
import Vapor

struct RequestService: Sendable {
    let id = UUID()
    let request: Request
}
#endif
