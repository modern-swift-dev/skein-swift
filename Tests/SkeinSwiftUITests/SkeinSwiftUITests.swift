#if canImport(SwiftUI)
import AppKit
import Skein
import SkeinSwiftUI
import SwiftUI
import XCTest

final class SkeinSwiftUITests: XCTestCase {
    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testMissingEnvironmentIsRepresentedAsTypedFailure() {
        let appeared = expectation(description: "view appeared")
        let host = NSHostingController(rootView: ProbeView { model, result in
            XCTAssertNil(model)
            guard case let .failure(error)? = result else {
                XCTFail("Expected a retained failure")
                return
            }
            XCTAssertEqual(error as? SkeinSwiftUIError, .missingApplication)
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
            XCTAssertEqual(error as? SkeinSwiftUIError, .missingApplication)
            appeared.fulfill()
        })
        host.view.layoutSubtreeIfNeeded()
        wait(for: [appeared], timeout: 1)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testEnvironmentModifierAcceptsAnApplication() throws {
        let definitions = Module {
            factory(TestModel.self) { _ in TestModel() }
        }
        let application = try SkeinApplication {
            definitions
        }
        _ = EmptyView().skeinApplication(application)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testEnvironmentResolvesAssistedModelOnce() throws {
        let application = try SkeinApplication {
            module {
                factory(
                    TestModel.self,
                    arguments: Int.self,
                    provider: { _, value in TestModel(value: value) }
                )
            }
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
            .skeinApplication(application)
        )
        host.view.layoutSubtreeIfNeeded()
        wait(for: [appeared], timeout: 1)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testExplicitInstanceNeedsNoApplication() {
        let model = TestModel(value: 84)
        let appeared = expectation(description: "view appeared")
        let host = NSHostingController(
            rootView: ExplicitProbeView(model: model) { resolved, result in
                XCTAssertTrue(resolved === model)
                guard case let .success(retained)? = result else {
                    return XCTFail("Expected the explicit model to be retained as a success")
                }
                XCTAssertTrue(retained === model)
                appeared.fulfill()
            }
        )
        host.view.layoutSubtreeIfNeeded()
        wait(for: [appeared], timeout: 1)
    }

    @available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
    @MainActor func testExplicitInstanceForwardsModelChanges() {
        let model = TestModel(value: 1)
        let appeared = expectation(description: "view appeared")
        let changed = expectation(description: "model change observed")
        let host = NSHostingController(
            rootView: ObservationProbeView(model: model) { value in
                if value == 1 { appeared.fulfill() }
                if value == 2 { changed.fulfill() }
            }
        )
        host.view.layoutSubtreeIfNeeded()
        wait(for: [appeared], timeout: 1)

        model.value = 2
        host.view.layoutSubtreeIfNeeded()
        wait(for: [changed], timeout: 1)
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *)
@MainActor private final class TestModel: ObservableObject {
    @Published var value: Int
    init(value: Int = 0) {
        self.value = value
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct ProbeView: View {
    @SkeinStateObject<TestModel> private var model: TestModel?
    let inspect: (TestModel?, Result<TestModel, Error>?) -> Void

    init(inspect: @escaping (TestModel?, Result<TestModel, Error>?) -> Void) {
        _model = .resolving()
        self.inspect = inspect
    }

    var body: some View {
        Color.clear.onAppear { inspect(model, $model) }
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct AssistedProbeView: View {
    @SkeinStateObject<TestModel> private var model: TestModel?
    let inspect: (TestModel?, Result<TestModel, Error>?) -> Void

    init(
        arguments: Int,
        inspect: @escaping (TestModel?, Result<TestModel, Error>?) -> Void
    ) {
        _model = .resolving(arguments: arguments)
        self.inspect = inspect
    }

    var body: some View {
        Color.clear.onAppear { inspect(model, $model) }
    }
}


@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct ExplicitProbeView: View {
    @SkeinStateObject<TestModel> private var model: TestModel?
    let inspect: (TestModel?, Result<TestModel, Error>?) -> Void

    @MainActor init(
        model: TestModel,
        inspect: @escaping (TestModel?, Result<TestModel, Error>?) -> Void
    ) {
        _model = .instance(model)
        self.inspect = inspect
    }

    var body: some View {
        Color.clear.onAppear { inspect(model, $model) }
    }
}

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, visionOS 1, *) private struct ObservationProbeView: View {
    @SkeinStateObject<TestModel> private var model: TestModel?
    let inspect: (Int?) -> Void

    @MainActor init(model: TestModel, inspect: @escaping (Int?) -> Void) {
        _model = .instance(model)
        self.inspect = inspect
    }

    var body: some View {
        Color.clear
            .onAppear { inspect(model?.value) }
            .onChange(of: model?.value) { _, value in inspect(value) }
    }
}
#endif
