#if canImport(AppKit) || (canImport(UIKit) && !os(watchOS))
    import Observation
    import Skein
    import SkeinSwiftUI
    import SwiftUI
    import XCTest

    final class SkeinStateTests: XCTestCase {
        @Observable @MainActor final class CounterModel {
            var value: Int

            init(value: Int) {
                self.value = value
            }
        }

        enum CounterQualifier: SkeinQualifier {
            case alternate
        }

        struct CounterFailure: Error {}

        @MainActor final class Recorder {
            private(set) var results: [Result<CounterModel, Error>?] = []
            var onRecord: ((Result<CounterModel, Error>?) -> Void)?

            func record(_ result: Result<CounterModel, Error>?) {
                results.append(result)
                onRecord?(result)
            }

            var lastValue: Int? {
                guard case let .success(model)?? = results.last else {
                    return nil
                }
                return model.value
            }
        }

        @MainActor final class ApplicationHolder: ObservableObject {
            @Published var application: SkeinApplication?
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        struct ProbeView: View {
            @SkeinState<CounterModel> private var model: CounterModel?
            let recorder: Recorder

            init(recorder: Recorder, state: SkeinState<CounterModel>) {
                _model = state
                self.recorder = recorder
            }

            var body: some View {
                recorder.record($model)
                return Text(model.map { "\($0.value)" } ?? "missing")
            }
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        struct HostView<Content: View>: View {
            @ObservedObject var holder: ApplicationHolder
            @ViewBuilder let content: () -> Content

            var body: some View {
                content().environment(\.skeinApplication, holder.application)
            }
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testResolvesPlainQualifiedAndAssistedBindingsFromTheEnvironment() throws {
            let application = try SkeinApplication {
                module {
                    factory(CounterModel.self, provider: { _ in CounterModel(value: 1) })
                    factory(CounterModel.self, qualifier: CounterQualifier.alternate, provider: { _ in CounterModel(value: 2) })
                    factory(CounterModel.self, arguments: Int.self, provider: { _, value in CounterModel(value: value) })
                }
            }
            let plain = Recorder()
            let qualified = Recorder()
            let assisted = Recorder()
            let host = TestViewHost(
                rootView: VStack {
                    ProbeView(recorder: plain, state: .resolving())
                    ProbeView(recorder: qualified, state: .resolving(qualifier: CounterQualifier.alternate))
                    ProbeView(recorder: assisted, state: .resolving(arguments: 3))
                }
                .skeinApplication(application)
            )
            defer { host.close() }
            host.layout()

            XCTAssertEqual(plain.lastValue, 1)
            XCTAssertEqual(qualified.lastValue, 2)
            XCTAssertEqual(assisted.lastValue, 3)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testExplicitInstanceNeedsNoApplication() {
            let model = CounterModel(value: 9)
            let recorder = Recorder()
            let host = TestViewHost(rootView: ProbeView(recorder: recorder, state: .instance(model)))
            defer { host.close() }
            host.layout()

            guard case let .success(retained)?? = recorder.results.last else {
                return XCTFail("Expected the explicit model to be retained")
            }
            XCTAssertTrue(retained === model)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testMissingApplicationFailureIsRetriedWhenApplicationAppears() throws {
            let calls = CallCount()
            let application = try SkeinApplication {
                module {
                    factory(CounterModel.self, provider: { _ in
                        calls.value += 1
                        return CounterModel(value: 5)
                    })
                }
            }
            let holder = ApplicationHolder()
            let recorder = Recorder()
            let host = TestViewHost(rootView: HostView(holder: holder) {
                ProbeView(recorder: recorder, state: .resolving())
            })
            defer { host.close() }
            host.layout()
            guard case let .failure(error)?? = recorder.results.last else {
                return XCTFail("Expected a missing-application failure first")
            }
            XCTAssertEqual(error as? SkeinSwiftUIError, .missingApplication)

            let resolved = expectation(description: "resolved after the application appeared")
            resolved.assertForOverFulfill = false
            recorder.onRecord = { result in
                if case .success? = result {
                    resolved.fulfill()
                }
            }
            holder.application = application
            wait(for: [resolved], timeout: 1)

            XCTAssertEqual(recorder.lastValue, 5)
            XCTAssertEqual(calls.value, 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testProviderFailureIsNotRetried() throws {
            let calls = CallCount()
            let definitions = Module {
                factory(CounterModel.self, provider: { _ -> CounterModel in
                    calls.value += 1
                    throw CounterFailure()
                })
            }
            let holder = ApplicationHolder()
            holder.application = try SkeinApplication { definitions }
            let recorder = Recorder()
            let host = TestViewHost(rootView: HostView(holder: holder) {
                ProbeView(recorder: recorder, state: .resolving())
            })
            defer { host.close() }
            host.layout()

            let updated = expectation(description: "updated with another application")
            updated.assertForOverFulfill = false
            recorder.onRecord = { _ in updated.fulfill() }
            holder.application = try SkeinApplication { definitions }
            wait(for: [updated], timeout: 1)

            XCTAssertEqual(calls.value, 1)
            guard case let .failure(error)?? = recorder.results.last else {
                return XCTFail("Expected the provider failure to stay retained")
            }
            XCTAssertNotNil(error as? SkeinResolutionError)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testViewRerendersWhenAnObservedPropertyChanges() {
            let model = CounterModel(value: 1)
            let recorder = Recorder()
            let host = TestViewHost(rootView: ProbeView(recorder: recorder, state: .instance(model)))
            defer { host.close() }
            host.layout()
            XCTAssertEqual(recorder.lastValue, 1)

            let rerendered = expectation(description: "re-rendered after the model changed")
            rerendered.assertForOverFulfill = false
            recorder.onRecord = { _ in
                if recorder.lastValue == 2 {
                    rerendered.fulfill()
                }
            }
            model.value = 2
            host.layout()
            wait(for: [rerendered], timeout: 1)
        }

        @MainActor final class CallCount {
            var value = 0
        }
    }
#endif
