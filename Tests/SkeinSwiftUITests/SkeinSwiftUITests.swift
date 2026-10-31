#if canImport(AppKit) || (canImport(UIKit) && !os(watchOS))
    import Combine
    import Skein
    import SkeinSwiftUI
    import SwiftUI
    import XCTest

    final class SkeinSwiftUITests: XCTestCase {
        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testMissingEnvironmentIsRepresentedAsTypedFailure() {
            let appeared = expectation(description: "view appeared")
            let host = TestViewHost(rootView: ProbeView { model, result in
                XCTAssertNil(model)
                guard case let .failure(error)? = result else {
                    XCTFail("Expected a retained failure")
                    return
                }
                XCTAssertEqual(error as? SkeinSwiftUIError, .missingApplication)
                appeared.fulfill()
            })
            defer { host.close() }
            host.layout()
            wait(for: [appeared], timeout: 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testAssistedInitializerCanRetainMissingEnvironmentFailure() {
            let appeared = expectation(description: "view appeared")
            let host = TestViewHost(rootView: AssistedProbeView(arguments: 42) { model, result in
                XCTAssertNil(model)
                guard case let .failure(error)? = result else {
                    XCTFail("Expected a retained failure")
                    return
                }
                XCTAssertEqual(error as? SkeinSwiftUIError, .missingApplication)
                appeared.fulfill()
            })
            defer { host.close() }
            host.layout()
            wait(for: [appeared], timeout: 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testEnvironmentModifierAcceptsAnApplication() throws {
            let definitions = Module {
                factory(TestModel.self) { _ in TestModel() }
            }
            let application = try SkeinApplication {
                definitions
            }
            _ = EmptyView().skeinApplication(application)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
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
            let host = TestViewHost(
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
            defer { host.close() }
            host.layout()
            wait(for: [appeared], timeout: 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testExplicitInstanceNeedsNoApplication() {
            let model = TestModel(value: 84)
            let appeared = expectation(description: "view appeared")
            let host = TestViewHost(
                rootView: ExplicitProbeView(model: model) { resolved, result in
                    XCTAssertTrue(resolved === model)
                    guard case let .success(retained)? = result else {
                        return XCTFail("Expected the explicit model to be retained as a success")
                    }
                    XCTAssertTrue(retained === model)
                    appeared.fulfill()
                }
            )
            defer { host.close() }
            host.layout()
            wait(for: [appeared], timeout: 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testExplicitInstanceForwardsModelChanges() {
            let model = TestModel(value: 1)
            let appeared = expectation(description: "view appeared")
            let changed = expectation(description: "model change observed")
            let host = TestViewHost(
                rootView: ObservationProbeView(model: model) { value in
                    if value == 1 {
                        appeared.fulfill()
                    }
                    if value == 2 {
                        changed.fulfill()
                    }
                }
            )
            defer { host.close() }
            host.layout()
            wait(for: [appeared], timeout: 1)

            model.value = 2
            host.layout()
            wait(for: [changed], timeout: 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testMainThreadModelChangeInvalidatesViewSynchronously() {
            let model = TestModel(value: 1)
            let recorder = BodyRecorder()
            let host = TestViewHost(rootView: RenderProbeView(model: model, recorder: recorder))
            defer { host.close() }
            host.layout()
            XCTAssertEqual(recorder.values.last, 1)

            model.value = 2
            host.layout()

            XCTAssertEqual(recorder.values.last, 2, "The view must observe a main-thread change without waiting for a later run-loop turn")
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testBackgroundModelChangeIsForwardedOnMainActor() {
            let model = BackgroundPublishingModel()
            let recorder = BodyRecorder()
            let host = TestViewHost(rootView: BackgroundRenderProbeView(model: model, recorder: recorder))
            defer { host.close() }
            host.layout()
            let initialRenders = recorder.values.count
            XCTAssertGreaterThan(initialRenders, 0)

            let rerendered = expectation(description: "view rendered after a background change")
            rerendered.assertForOverFulfill = false
            recorder.onRecord = {
                XCTAssertTrue(Thread.isMainThread)
                rerendered.fulfill()
            }
            DispatchQueue.global().async {
                model.objectWillChange.send()
            }
            wait(for: [rerendered], timeout: 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testMissingApplicationFailureIsRetriedWhenApplicationAppears() throws {
            let calls = CallCounter()
            let application = try SkeinApplication {
                module {
                    factory(TestModel.self) { _ in
                        calls.value += 1
                        return TestModel(value: 7)
                    }
                }
            }
            let holder = ApplicationHolder()
            let recorder = ResultRecorder()
            let host = TestViewHost(rootView: EnvironmentSwitchingView(holder: holder) {
                ResultProbeView(recorder: recorder)
            })
            defer { host.close() }
            host.layout()
            guard case let .failure(error)?? = recorder.results.last else {
                return XCTFail("Expected a missing-application failure on the first update")
            }
            XCTAssertEqual(error as? SkeinSwiftUIError, .missingApplication)

            let resolved = expectation(description: "model resolved after the application appeared")
            resolved.assertForOverFulfill = false
            recorder.onRecord = { result in
                if case .success? = result {
                    resolved.fulfill()
                }
            }
            holder.application = application
            wait(for: [resolved], timeout: 1)

            guard case let .success(model)?? = recorder.results.last else {
                return XCTFail("Expected the model to resolve once an application is present")
            }
            XCTAssertEqual(model.value, 7)
            XCTAssertEqual(calls.value, 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testProviderFailureIsNotRetriedOnLaterUpdates() throws {
            let calls = CallCounter()
            let definitions = Module {
                factory(TestModel.self) { _ -> TestModel in
                    calls.value += 1
                    throw TestProviderFailure()
                }
            }
            let first = try SkeinApplication { definitions }
            let second = try SkeinApplication { definitions }
            let holder = ApplicationHolder()
            holder.application = first
            let recorder = ResultRecorder()
            let host = TestViewHost(rootView: EnvironmentSwitchingView(holder: holder) {
                ResultProbeView(recorder: recorder)
            })
            defer { host.close() }
            host.layout()
            XCTAssertEqual(calls.value, 1)

            let updated = expectation(description: "view updated with another application")
            updated.assertForOverFulfill = false
            recorder.onRecord = { _ in updated.fulfill() }
            holder.application = second
            wait(for: [updated], timeout: 1)

            XCTAssertEqual(calls.value, 1)
            guard case let .failure(error)?? = recorder.results.last else {
                return XCTFail("Expected the provider failure to stay cached")
            }
            XCTAssertNotNil(error as? SkeinResolutionError)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testExplicitInstanceIgnoresApplicationAppearingLater() throws {
            let explicit = TestModel(value: 3)
            let application = try SkeinApplication {
                module {
                    factory(TestModel.self) { _ in TestModel(value: 9) }
                }
            }
            let holder = ApplicationHolder()
            let recorder = ResultRecorder()
            let host = TestViewHost(rootView: EnvironmentSwitchingView(holder: holder) {
                ResultProbeView(recorder: recorder, model: explicit)
            })
            defer { host.close() }
            host.layout()

            let updated = expectation(description: "view updated with an application")
            updated.assertForOverFulfill = false
            recorder.onRecord = { _ in updated.fulfill() }
            holder.application = application
            wait(for: [updated], timeout: 1)

            guard case let .success(model)?? = recorder.results.last else {
                return XCTFail("Expected the explicit model to stay retained")
            }
            XCTAssertTrue(model === explicit)
        }
    }

    private struct TestProviderFailure: Error {}

    @MainActor private final class CallCounter {
        var value = 0
    }

    @MainActor private final class ApplicationHolder: ObservableObject {
        @Published var application: SkeinApplication?
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
    @MainActor private final class ResultRecorder {
        private(set) var results: [Result<TestModel, Error>?] = []
        var onRecord: ((Result<TestModel, Error>?) -> Void)?

        func record(_ result: Result<TestModel, Error>?) {
            results.append(result)
            onRecord?(result)
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct EnvironmentSwitchingView<Content: View>: View {
        @ObservedObject var holder: ApplicationHolder
        @ViewBuilder let content: () -> Content

        var body: some View {
            content().environment(\.skeinApplication, holder.application)
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct ResultProbeView: View {
        @SkeinStateObject<TestModel> private var model: TestModel?
        let recorder: ResultRecorder

        @MainActor init(recorder: ResultRecorder) {
            _model = .resolving()
            self.recorder = recorder
        }

        @MainActor init(recorder: ResultRecorder, model: TestModel) {
            _model = .instance(model)
            self.recorder = recorder
        }

        var body: some View {
            recorder.record($model)
            return Text(model.map { "\($0.value)" } ?? "missing")
        }
    }

    @MainActor private final class BodyRecorder {
        private(set) var values: [Int?] = []
        var onRecord: (() -> Void)?

        func record(_ value: Int?) {
            values.append(value)
            onRecord?()
        }
    }

    /// Publishes changes from arbitrary threads.
    ///
    /// `@unchecked Sendable` is justified because the model holds no state besides its
    /// publisher, and `ObservableObjectPublisher.send()` may be called from any thread.
    private final class BackgroundPublishingModel: ObservableObject, @unchecked Sendable {
        let objectWillChange = ObservableObjectPublisher()
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct BackgroundRenderProbeView: View {
        @SkeinStateObject<BackgroundPublishingModel> private var model: BackgroundPublishingModel?
        let recorder: BodyRecorder

        @MainActor init(model: BackgroundPublishingModel, recorder: BodyRecorder) {
            _model = .instance(model)
            self.recorder = recorder
        }

        var body: some View {
            recorder.record(nil)
            return Text(model == nil ? "missing" : "present")
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct RenderProbeView: View {
        @SkeinStateObject<TestModel> private var model: TestModel?
        let recorder: BodyRecorder

        @MainActor init(model: TestModel, recorder: BodyRecorder) {
            _model = .instance(model)
            self.recorder = recorder
        }

        var body: some View {
            recorder.record(model?.value)
            return Text("\(model?.value ?? 0)")
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
    @MainActor private final class TestModel: ObservableObject {
        @Published var value: Int
        init(value: Int = 0) {
            self.value = value
        }
    }

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct ProbeView: View {
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

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct AssistedProbeView: View {
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

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct ExplicitProbeView: View {
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

    @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *) private struct ObservationProbeView: View {
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
