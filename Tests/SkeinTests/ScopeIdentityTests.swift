@testable import Skein
import XCTest

final class ScopeIdentityTests: XCTestCase {
    private struct DiagnosticID: Hashable, Sendable, CustomStringConvertible {
        let value: Int
        let label: String
        let descriptionReads: LockedCounter

        var description: String {
            descriptionReads.increment()
            return label
        }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.value == rhs.value
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(value)
        }
    }

    private enum OtherScope: SkeinScope {}

    func testScopeIdentityUsesScopeTypeAndIDWithoutFormattingDiagnostics() {
        let descriptionReads = LockedCounter()
        let first = ScopeIdentity(
            type: SeededScope.self,
            id: DiagnosticID(value: 1, label: "first", descriptionReads: descriptionReads)
        )
        let second = ScopeIdentity(
            type: SeededScope.self,
            id: DiagnosticID(value: 1, label: "second", descriptionReads: descriptionReads)
        )
        let otherKind = ScopeIdentity(
            type: OtherScope.self,
            id: DiagnosticID(value: 1, label: "first", descriptionReads: descriptionReads)
        )
        let otherID = ScopeIdentity(
            type: SeededScope.self,
            id: DiagnosticID(value: 2, label: "first", descriptionReads: descriptionReads)
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(Set([first, second, otherKind, otherID]).count, 3)
        XCTAssertEqual(descriptionReads.value, 0)
        XCTAssertEqual(first.idDescription, "first")
        XCTAssertEqual(first.typeName, String(reflecting: SeededScope.self))
        XCTAssertEqual(descriptionReads.value, 1)
    }

    @MainActor func testEqualScopeIDsWithDifferentDescriptionsRejectDuplicatesAndPermitReplacementAfterClosing() async throws {
        let descriptionReads = LockedCounter()
        let application = try SkeinApplication {}
        let firstID = DiagnosticID(value: 1, label: "first", descriptionReads: descriptionReads)
        let secondID = DiagnosticID(value: 1, label: "second", descriptionReads: descriptionReads)
        let scope = try application.createScope(SeededScope.self, id: firstID)
        XCTAssertEqual(descriptionReads.value, 0)

        XCTAssertThrowsError(try application.createScope(SeededScope.self, id: secondID)) {
            XCTAssertEqual(
                $0 as? SkeinError,
                .duplicateScope(scope: String(reflecting: SeededScope.self), id: "second")
            )
        }

        await scope.close()
        let replacement = try application.createScope(SeededScope.self, id: secondID)
        await replacement.close()
        await application.close()
    }
}
