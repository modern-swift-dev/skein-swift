#if canImport(SwiftUI) && DEBUG
    import Skein
    @testable import SkeinSwiftUI
    import XCTest

    /// Pins the shared retry rule of `SkeinStateObject` and `SkeinState`.
    final class ResolutionStateTests: XCTestCase {
        @MainActor final class Model {}

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testMissingScopeIsRetriedUntilResolutionSucceeds() {
            var attempts = 0
            let model = Model()
            let request = makeRequest {
                attempts += 1
                if attempts == 1 {
                    throw SkeinSwiftUIError.missingScope(scope: "SessionScope")
                }
                return model
            }
            let state = ResolutionState(request: request, wrapperName: "Test")

            state.resolveIfNeeded(environment: emptyEnvironment, request: request)
            XCTAssertNil(state.model)
            state.resolveIfNeeded(environment: emptyEnvironment, request: request)
            state.resolveIfNeeded(environment: emptyEnvironment, request: request)

            XCTAssertTrue(state.model === model)
            XCTAssertEqual(attempts, 2)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor func testScopeCreationFailureIsNotRetried() {
            var attempts = 0
            let failure = SkeinSwiftUIError.scopeCreationFailed(scope: "SessionScope", underlying: .applicationClosed)
            let request = makeRequest { () throws -> Model in
                attempts += 1
                throw failure
            }
            let state = ResolutionState(request: request, wrapperName: "Test")

            state.resolveIfNeeded(environment: emptyEnvironment, request: request)
            state.resolveIfNeeded(environment: emptyEnvironment, request: request)

            XCTAssertEqual(attempts, 1)
            guard case let .failure(error)? = state.result else {
                return XCTFail("Expected the scope-creation failure to be kept")
            }
            XCTAssertEqual(error as? SkeinSwiftUIError, failure)
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor private var emptyEnvironment: WrapperEnvironment {
            WrapperEnvironment(application: nil, scopes: SkeinScopeEnvironment())
        }

        @available(iOS 17, tvOS 17, macOS 15, watchOS 10, visionOS 1, *)
        @MainActor private func makeRequest(_ resolve: @escaping () throws -> Model) -> ResolutionRequest<Model> {
            ResolutionRequest(
                configuration: ResolutionConfiguration(
                    source: .resolution,
                    scope: nil,
                    qualifier: nil,
                    argumentsDescription: nil,
                    argumentsType: nil
                ),
                usesEnvironment: true,
                resolve: { _ in try resolve() },
                initialResult: nil
            )
        }
    }
#endif
