import Skein
import XCTest

final class BindingKeyTests: XCTestCase {
    private enum Qualifier: SkeinQualifier, CustomStringConvertible {
        case first
        case second

        var description: String {
            "same-description"
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(0)
        }
    }

    private enum OtherQualifier: SkeinQualifier, CustomStringConvertible {
        case first

        var description: String {
            "same-description"
        }
    }

    func testGenericAndErasedKeysHaveMatchingIdentity() {
        let generic = BindingKey([String: Int].self, qualifier: Qualifier.first, argumentType: Int?.self)
        let erased = BindingKey(anyType: [String: Int].self, qualifier: Qualifier.first, argumentType: Int?.self)

        XCTAssertEqual(generic, erased)
        XCTAssertEqual(Set([generic, erased]).count, 1)
        XCTAssertEqual(generic.type, ObjectIdentifier([String: Int].self))
        XCTAssertEqual(generic.argumentType, ObjectIdentifier(Int?.self))
    }

    func testLookupKeepsServiceQualifierAndArgumentIdentitiesDistinct() {
        let keys = [
            BindingKey(String.self, qualifier: nil),
            BindingKey(Int.self, qualifier: nil),
            BindingKey(String.self, qualifier: Qualifier.first),
            BindingKey(String.self, qualifier: Qualifier.second),
            BindingKey(String.self, qualifier: OtherQualifier.first),
            BindingKey(String.self, qualifier: nil, argumentType: Int.self),
            BindingKey(String.self, qualifier: nil, argumentType: Int?.self),
            BindingKey(String.self, qualifier: Qualifier.first, argumentType: Int.self)
        ]
        let values = Dictionary(uniqueKeysWithValues: keys.enumerated().map { ($0.element, $0.offset) })

        XCTAssertEqual(values.count, keys.count)
        for (index, key) in keys.enumerated() {
            XCTAssertEqual(values[key], index)
        }
        XCTAssertEqual(
            values[BindingKey(anyType: String.self, qualifier: Qualifier.second)],
            3
        )
    }

    func testDiagnosticNamesPreserveServiceQualifierAndAssistedTypes() {
        let key = BindingKey([String: Int].self, qualifier: Qualifier.first, argumentType: Int?.self)
        let typeName = String(reflecting: [String: Int].self)
        let argumentName = String(reflecting: Int?.self)
        let qualifierName = String(reflecting: Qualifier.self)

        XCTAssertEqual(key.typeName, typeName)
        XCTAssertEqual(key.argumentTypeName, argumentName)
        XCTAssertEqual(key.qualifier?.typeName, qualifierName)
        XCTAssertEqual(key.qualifier?.description, "\(qualifierName).same-description")
        XCTAssertEqual(key.description, "\(typeName) (arguments: \(argumentName)) [\(qualifierName).same-description]")

        let ordinary = BindingKey(String.self, qualifier: nil)
        XCTAssertNil(ordinary.argumentType)
        XCTAssertNil(ordinary.argumentTypeName)
        XCTAssertEqual(ordinary.description, String(reflecting: String.self))
    }
}
