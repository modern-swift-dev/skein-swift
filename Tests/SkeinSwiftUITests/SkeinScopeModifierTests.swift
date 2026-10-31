#if canImport(AppKit) || (canImport(UIKit) && !os(watchOS))
    import Observation
    import Skein
    import SkeinSwiftUI
    import SwiftUI
    import XCTest

    final class SkeinScopeModifierTests: XCTestCase {
        enum SessionScope: SkeinScope {}

        @MainActor final class SessionModel: ObservableObject {
            let value: Int

            init(value: Int) {
                self.value = value
            }
        }

        @Observable @MainActor final class ObservedSession {
            var name = "observed"
        }

        @MainActor final class Counter {
            var value = 0
        }

        @MainActor final class Recorder {
            private(set) var results: [Result<SessionModel, Error>?] = []
            var onRecord: (() -> Void)?

            func record(_ result: Result<SessionModel, Error>?) {
                results.append(result)
                onRecord?()
            }

            var lastModel: SessionModel? {
                guard case let .success(model)?? = results.last else {
                    return nil
                }
                return model
            }

            var lastError: Error? {
                guard case let .failure(error)?? = results.last else {
                    return nil
                }
                return error
            }
        }

        @MainActor final class Controls: ObservableObject {
            @Published var application: SkeinApplication?
            @Published var showsScope = true
            @Published var scopeID = 1
            @Published var generation = 0
            @Published var tick = 0
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        struct SessionProbe: View {
            @SkeinStateObject<SessionModel> private var model: SessionModel?
            let recorder: Recorder

            init(recorder: Recorder, state: SkeinStateObject<SessionModel> = .resolving(in: SessionScope.self)) {
                _model = state
                self.recorder = recorder
            }

            var body: some View {
                recorder.record($model)
                return Text(model.map { "\($0.value)" } ?? "missing")
            }
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        struct ObservedProbe: View {
            @SkeinState<ObservedSession> private var session: ObservedSession?
            let inspect: (ObservedSession?) -> Void

            init(inspect: @escaping (ObservedSession?) -> Void) {
                _session = .resolving(in: SessionScope.self)
                self.inspect = inspect
            }

            var body: some View {
                inspect(session)
                return Text(session?.name ?? "missing")
            }
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        struct ControlledHost<Content: View>: View {
            @ObservedObject var controls: Controls
            @ViewBuilder let content: (Controls) -> Content

            var body: some View {
                Group {
                    if controls.showsScope {
                        content(controls)
                            .skeinScope(SessionScope.self, id: controls.scopeID)
                            .id(controls.generation)
                    }
                    Text("\(controls.tick)")
                }
                .environment(\.skeinApplication, controls.application)
            }
        }

        // MARK: Resolution from the view-owned scope

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testDescendantsShareTheViewOwnedScope() throws {
            let creations = Counter()
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in
                        creations.value += 1
                        return SessionModel(value: creations.value)
                    }
                    scoped(SessionScope.self, ObservedSession.self) { _ in ObservedSession() }
                    factory(SessionModel.self, arguments: Int.self, provider: { _, value in SessionModel(value: value) })
                }
            }
            let first = Recorder()
            let second = Recorder()
            let assisted = Recorder()
            var observed: ObservedSession?
            let host = TestViewHost(
                rootView: VStack {
                    SessionProbe(recorder: first)
                    SessionProbe(recorder: second)
                    SessionProbe(recorder: assisted, state: .resolving(in: SessionScope.self, arguments: 40))
                    ObservedProbe { observed = $0 }
                }
                .skeinScope(SessionScope.self, id: 1)
                .skeinApplication(application)
            )
            defer { host.close() }
            host.layout()

            let firstModel = try XCTUnwrap(first.lastModel)
            XCTAssertTrue(firstModel === second.lastModel)
            XCTAssertEqual(creations.value, 1)
            XCTAssertEqual(assisted.lastModel?.value, 40)
            XCTAssertEqual(observed?.name, "observed")
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testSeededScopeServesTheSeedWithoutRunningTheProvider() throws {
            let creations = Counter()
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in
                        creations.value += 1
                        return SessionModel(value: 0)
                    }
                }
            }
            let seed = SessionModel(value: 99)
            let recorder = Recorder()
            let host = TestViewHost(
                rootView: SessionProbe(recorder: recorder)
                    .skeinScope(SessionScope.self, id: 1, seeding: seed, as: SessionModel.self)
                    .skeinApplication(application)
            )
            defer { host.close() }
            host.layout()

            XCTAssertTrue(recorder.lastModel === seed)
            XCTAssertEqual(creations.value, 0)
        }

        // MARK: Lifetime

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testRemovingTheOwningViewClosesTheScopeOnce() throws {
            let disposals = Counter()
            let disposed = expectation(description: "scope disposed after removal")
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self, onClose: { _ in
                        disposals.value += 1
                        disposed.fulfill()
                    }, provider: { _ in SessionModel(value: 1) })
                }
            }
            let controls = Controls()
            controls.application = application
            let recorder = Recorder()
            let host = TestViewHost(rootView: ControlledHost(controls: controls) { _ in SessionProbe(recorder: recorder) })
            defer { host.close() }
            host.layout()
            XCTAssertNotNil(recorder.lastModel)

            controls.tick += 1
            host.layout()
            XCTAssertEqual(disposals.value, 0, "Re-rendering must not close the scope")

            controls.showsScope = false
            host.layout()
            wait(for: [disposed], timeout: 2)
            XCTAssertEqual(disposals.value, 1)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testReplacingTheOwningViewWithTheSameIDCreatesAFreshScope() throws {
            let disposals = Counter()
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self, onClose: { _ in disposals.value += 1 }, provider: { _ in
                        SessionModel(value: 1)
                    })
                }
            }
            let controls = Controls()
            controls.application = application
            let recorder = Recorder()
            let host = TestViewHost(rootView: ControlledHost(controls: controls) { _ in SessionProbe(recorder: recorder) })
            defer { host.close() }
            host.layout()
            let original = try XCTUnwrap(recorder.lastModel)

            let replaced = expectation(description: "replacement resolved")
            replaced.assertForOverFulfill = false
            recorder.onRecord = {
                if let model = recorder.lastModel, model !== original {
                    replaced.fulfill()
                }
            }
            controls.generation += 1
            wait(for: [replaced], timeout: 2)

            XCTAssertNil(recorder.lastError, "Re-creating the same scope ID must not fail with duplicateScope")
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testReinsertingTheOwningViewInALaterUpdateCreatesAFreshScope() throws {
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in SessionModel(value: 1) }
                }
            }
            let controls = Controls()
            controls.application = application
            let recorder = Recorder()
            let host = TestViewHost(rootView: ControlledHost(controls: controls) { _ in SessionProbe(recorder: recorder) })
            defer { host.close() }
            host.layout()
            let original = try XCTUnwrap(recorder.lastModel)

            controls.showsScope = false
            host.layout()
            let reinserted = expectation(description: "re-inserted view resolved")
            reinserted.assertForOverFulfill = false
            recorder.onRecord = {
                if recorder.results.last != nil {
                    reinserted.fulfill()
                }
            }
            controls.showsScope = true
            wait(for: [reinserted], timeout: 2)

            XCTAssertNil(recorder.lastError, "Re-inserting the same scope ID must not fail with duplicateScope")
            XCTAssertFalse(recorder.lastModel === original)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testChangingTheIDKeepsTheOriginalScope() throws {
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in SessionModel(value: 1) }
                }
            }
            let controls = Controls()
            controls.application = application
            let recorder = Recorder()
            let host = TestViewHost(rootView: ControlledHost(controls: controls) { _ in SessionProbe(recorder: recorder) })
            defer { host.close() }
            host.layout()
            let original = try XCTUnwrap(recorder.lastModel)

            let updated = expectation(description: "re-rendered with a new ID")
            updated.assertForOverFulfill = false
            recorder.onRecord = { updated.fulfill() }
            controls.scopeID = 2
            wait(for: [updated], timeout: 1)

            XCTAssertTrue(recorder.lastModel === original)
        }

        // MARK: Failures

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testScopeIsCreatedOnceAnApplicationAppears() throws {
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in SessionModel(value: 3) }
                }
            }
            let controls = Controls()
            let recorder = Recorder()
            let host = TestViewHost(rootView: ControlledHost(controls: controls) { _ in SessionProbe(recorder: recorder) })
            defer { host.close() }
            host.layout()
            XCTAssertEqual(recorder.lastError as? SkeinSwiftUIError, .missingApplication)

            let resolved = expectation(description: "resolved after the application appeared")
            resolved.assertForOverFulfill = false
            recorder.onRecord = {
                if recorder.lastModel != nil {
                    resolved.fulfill()
                }
            }
            controls.application = application
            wait(for: [resolved], timeout: 1)
            XCTAssertEqual(recorder.lastModel?.value, 3)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testWrapperWithoutAScopeReportsMissingScope() throws {
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in SessionModel(value: 1) }
                }
            }
            let recorder = Recorder()
            let host = TestViewHost(rootView: SessionProbe(recorder: recorder).skeinApplication(application))
            defer { host.close() }
            host.layout()

            XCTAssertEqual(
                recorder.lastError as? SkeinSwiftUIError,
                .missingScope(scope: String(reflecting: SessionScope.self))
            )
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testScopeCreationFailureIsKept() throws {
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in SessionModel(value: 1) }
                }
            }
            let controls = Controls()
            controls.application = application
            let recorder = Recorder()
            // Seeding a type with no scoped binding makes scope creation fail.
            let host = TestViewHost(rootView: ControlledHost(controls: controls) { _ in
                SessionProbe(recorder: recorder)
                    .skeinScope(SessionScope.self, id: 7, seeding: "unbound", as: String.self)
            })
            defer { host.close() }
            host.layout()

            let expected = SkeinSwiftUIError.scopeCreationFailed(
                scope: String(reflecting: SessionScope.self),
                underlying: .missingBinding(type: String(reflecting: String.self), qualifier: nil)
            )
            XCTAssertEqual(recorder.lastError as? SkeinSwiftUIError, expected)

            let updated = expectation(description: "re-rendered")
            updated.assertForOverFulfill = false
            recorder.onRecord = { updated.fulfill() }
            controls.tick += 1
            wait(for: [updated], timeout: 1)
            XCTAssertEqual(recorder.lastError as? SkeinSwiftUIError, expected)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testViewOwnedScopesWithTheSameIDDoNotConflict() throws {
            let creations = Counter()
            let application = try SkeinApplication {
                module {
                    scoped(SessionScope.self, SessionModel.self) { _ in
                        creations.value += 1
                        return SessionModel(value: creations.value)
                    }
                }
            }
            let direct = try application.createScope(SessionScope.self, id: 1)
            let first = Recorder()
            let second = Recorder()
            let host = TestViewHost(
                rootView: VStack {
                    SessionProbe(recorder: first).skeinScope(SessionScope.self, id: 1)
                    SessionProbe(recorder: second).skeinScope(SessionScope.self, id: 1)
                }
                .skeinApplication(application)
            )
            defer { host.close() }
            host.layout()

            let firstModel = try XCTUnwrap(first.lastModel)
            let secondModel = try XCTUnwrap(second.lastModel)
            XCTAssertFalse(firstModel === secondModel)
            XCTAssertEqual(creations.value, 2)
            XCTAssertNoThrow(try direct.get(SessionModel.self, qualifier: nil))
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        func testScopeErrorDescriptionsNameTheScope() throws {
            let missing = try XCTUnwrap(SkeinSwiftUIError.missingScope(scope: "SessionScope").errorDescription)
            let failed = try XCTUnwrap(
                SkeinSwiftUIError.scopeCreationFailed(scope: "SessionScope", underlying: .applicationClosed).errorDescription
            )
            XCTAssertTrue(missing.contains("SessionScope"))
            XCTAssertTrue(missing.contains(".skeinScope("))
            XCTAssertTrue(failed.contains("SessionScope"))
        }
    }
#endif
