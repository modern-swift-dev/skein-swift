#if canImport(SwiftUI)
import AppKit
import Koin
import KoinSwiftUI
import SwiftUI
import XCTest

final class KoinSwiftUITests: XCTestCase {
    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testMissingEnvironmentIsRepresentedAsTypedFailure() {
        let appeared = expectation(description: "view appeared")
        let host = NSHostingController(rootView: ProbeView { model, result in
            XCTAssertNil(model)
            guard case let .failure(error)? = result else {
                XCTFail("Expected a retained failure")
                return
            }
            XCTAssertEqual(error as? KoinSwiftUIError, .missingApplication)
            appeared.fulfill()
        })
        host.view.layoutSubtreeIfNeeded()
        wait(for: [appeared], timeout: 1)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testAssistedInitializerCanRetainMissingEnvironmentFailure() {
        let appeared = expectation(description: "view appeared")
        let host = NSHostingController(rootView: AssistedProbeView(arguments: 42) { model, result in
            XCTAssertNil(model)
            guard case let .failure(error)? = result else {
                XCTFail("Expected a retained failure")
                return
            }
            XCTAssertEqual(error as? KoinSwiftUIError, .missingApplication)
            appeared.fulfill()
        })
        host.view.layoutSubtreeIfNeeded()
        wait(for: [appeared], timeout: 1)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testEnvironmentModifierAcceptsAnApplication() throws {
        let definitions = Module {
            mainActorFactory(TestModel.self) { _ in TestModel() }
        }
        let application = try KoinApplication {
            modules(definitions)
        }
        _ = EmptyView().koinApplication(application)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testEnvironmentResolvesAssistedModelOnce() throws {
        let application = try KoinApplication {
            modules(module {
                mainActorFactory(TestModel.self, arguments: Int.self) { _, value in
                    TestModel(value: value)
                }
            })
        }
        let appeared = expectation(description: "view appeared")
        appeared.expectedFulfillmentCount = 1
        let host = NSHostingController(
            rootView: AssistedProbeView(arguments: 42) { model, result in
                XCTAssertEqual(model?.value, 42)
                guard case let .success(resolved)? = result else {
                    XCTFail("Expected a retained success")
                    return
                }
                XCTAssertTrue(model === resolved)
                appeared.fulfill()
            }
            .koinApplication(application)
        )
        host.view.layoutSubtreeIfNeeded()
        wait(for: [appeared], timeout: 1)
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
@MainActor private final class TestModel: ObservableObject {
    let value: Int
    init(value: Int = 0) {
        self.value = value
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct ProbeView: View {
    @KoinStateObject<TestModel> private var model: TestModel?
    let inspect: (TestModel?, Result<TestModel, Error>?) -> Void

    init(inspect: @escaping (TestModel?, Result<TestModel, Error>?) -> Void) {
        self.inspect = inspect
    }

    var body: some View {
        Color.clear.onAppear { inspect(model, $model) }
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct AssistedProbeView: View {
    @KoinStateObject<TestModel> private var model: TestModel?
    let inspect: (TestModel?, Result<TestModel, Error>?) -> Void

    init(
        arguments: Int,
        inspect: @escaping (TestModel?, Result<TestModel, Error>?) -> Void
    ) {
        _model = KoinStateObject<TestModel>(arguments: arguments)
        self.inspect = inspect
    }

    var body: some View {
        Color.clear.onAppear { inspect(model, $model) }
    }
}
#endif
