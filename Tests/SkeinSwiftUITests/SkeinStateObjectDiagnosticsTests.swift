#if canImport(SwiftUI)
    import SkeinSwiftUI
    import SwiftUI
    import XCTest

    final class SkeinStateObjectDiagnosticsTests: XCTestCase {
        private final class DescriptionCounter {
            var value = 0
        }

        private struct DiagnosticArguments: CustomDebugStringConvertible {
            let counter: DescriptionCounter

            var debugDescription: String {
                counter.value += 1
                return "assisted arguments"
            }
        }

        private final class Model: ObservableObject {}

        @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
        @MainActor func testArgumentDescriptionsAreOnlyEvaluatedInDebugBuilds() {
            let counter = DescriptionCounter()

            _ = SkeinStateObject<Model>.resolving(arguments: DiagnosticArguments(counter: counter))

            #if DEBUG
                XCTAssertEqual(counter.value, 1)
            #else
                XCTAssertEqual(counter.value, 0)
            #endif
        }
    }
#endif
