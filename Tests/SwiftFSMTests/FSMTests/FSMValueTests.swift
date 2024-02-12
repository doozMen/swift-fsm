import XCTest
@testable import SwiftFSM

final class FSMValueTests: XCTestCase {
    let v1 = FSMValue<String>.any
    let v2 = FSMValue.some("1")
    let v3 = FSMValue.some("2")

    func testValue() {
        XCTAssertEqual(v1.wrappedValue, nil)
        XCTAssertEqual(v2.wrappedValue, "1")
        XCTAssertEqual(v3.wrappedValue, "2")
    }

    func testThrowingValue() {
        XCTAssertThrowsError(try v1.throwingWrappedValue()) {
            XCTAssertEqual($0.localizedDescription,
"""
FSMValue<String>.any has no value - performing operations on it as if it did is forbidden.
"""
            )
        }
        XCTAssertNoThrow(try v2.throwingWrappedValue())
        XCTAssertEqual(v2.unsafeWrappedValue, "1")
    }

    func testIsSome() {
        XCTAssertFalse(v1.isSome)
        XCTAssertTrue(v2.isSome)
    }

    func testEquality() {
        XCTAssertEqual(v1, v1)
        XCTAssertEqual(v1, v2)
        XCTAssertEqual(v1, v3)
        XCTAssertEqual(v2, v2)
        XCTAssertEqual(v3, v3)

        XCTAssertNotEqual(v2, v3)
    }

    func testConvenienceEquatable() {
        XCTAssertTrue(v2 == "1")
        XCTAssertTrue(v2 != "2")
        XCTAssertFalse(v2 != "1")
        XCTAssertFalse(v2 == "2")

        XCTAssertTrue("1" == v2)
        XCTAssertTrue("2" != v2)
        XCTAssertFalse("1" != v2)
        XCTAssertFalse("2" == v2)
    }

    func testConvenienceComparable() {
        XCTAssertFalse(.any > "1")
        XCTAssertTrue(v3 > "1")

        XCTAssertFalse(.any < "1")
        XCTAssertFalse(v3 < "1")

        XCTAssertFalse(.any <= "1")
        XCTAssertFalse(v3 <= "1")

        XCTAssertFalse(.any >= "1")
        XCTAssertTrue(v2 >= "1")

        XCTAssertFalse(.any > "1")
        XCTAssertFalse(v2 > "1")

        XCTAssertFalse(.any <= "1")
        XCTAssertTrue(v2 <= "1")

        XCTAssertFalse("1" < .any)
        XCTAssertTrue("1" < v3)

        XCTAssertFalse("1" > .any)
        XCTAssertFalse("1" > v3)

        XCTAssertFalse("1" >= .any)
        XCTAssertFalse("1" >= v3)

        XCTAssertFalse("1" <= .any)
        XCTAssertTrue("1" <= v2)

        XCTAssertFalse("1" < .any)
        XCTAssertFalse("1" < v2)

        XCTAssertFalse("1" >= .any)
        XCTAssertTrue("1" >= v2)
    }

    func testStringLiteral() {
        let s: FSMValue<String> = "1"
        let us: FSMValue<String> = .init(unicodeScalarLiteral: "1")
        let egc: FSMValue<String> = .init(extendedGraphemeClusterLiteral: "1")

        XCTAssertEqual(s, "1")
        XCTAssertEqual(us, "1")
        XCTAssertEqual(egc, "1")

        XCTAssertEqual(s + "1", "11")
        XCTAssertEqual("1" + s, "11")
    }

    func testIntLiteral() {
        let i8: FSMValue<Int8> = 1
        let i16: FSMValue<Int16> = 1
        let i32: FSMValue<Int32> = 1
        let i64: FSMValue<Int64> = 1
        let i: FSMValue<Int> = 1

        XCTAssertEqual(1, i8)
        XCTAssertEqual(1, i16)
        XCTAssertEqual(1, i32)
        XCTAssertEqual(1, i64)
        XCTAssertEqual(1, i)
    }

    func testFloatLiteral() {
        let f: FSMValue<Float> = 1.0
        let f32: FSMValue<Float32> = 1.0
        let f64: FSMValue<Float64> = 1.0
        let f80: FSMValue<Float80> = 1.0
        let d: FSMValue<Double> = 1.0

        XCTAssertEqual(1.0, f)
        XCTAssertEqual(1.0, f32)
        XCTAssertEqual(1.0, f64)
        XCTAssertEqual(1.0, f80)
        XCTAssertEqual(1.0, d)
    }

    func testArrayLiteralAndAccess() {
        let a1: FSMValue<[String]> = ["cat", "cat"]

        XCTAssertEqual(a1, ["cat", "cat"])
        XCTAssertEqual(a1[0], "cat")
        XCTAssertEqual(a1.first, "cat")
        XCTAssertTrue(a1.allSatisfy { $0 == "cat" })
        XCTAssertEqual(a1.index(after: 0), 1)
        XCTAssertEqual(a1.index(before: 1), 0)
    }

    func testDictionaryLiteralAndAccess() {
        let d1: FSMValue<[String: String]> = ["cat": "fish"]

        XCTAssertEqual(d1["cat"], "fish")
        XCTAssertEqual(d1["bat"], nil)
        XCTAssertEqual(d1["bat", default: "cat"], "cat")
    }

    func testBoolLiteral() {
        let b: FSMValue<Bool> = true
        XCTAssertEqual(true, b)
    }

    func testNilLiteral() {
        let optional: FSMValue<Bool?> = nil
        XCTAssertEqual(optional, nil)
    }

    func testAdditionSubtraction() {
        let i: FSMValue<Int> = 1

        XCTAssertEqual(i + 1, 2)
        XCTAssertEqual(1 + i, 2)
        XCTAssertEqual(i - 1, 0)
        XCTAssertEqual(1 - i, 0)
    }
}

final class EventWithValueTests: XCTestCase {
    enum Event: EventWithValues {
        case withValue(FSMValue<String>), withoutValue
    }

    let e1 = Event.withValue(.some("1"))
    let e2 = Event.withValue(.some("2"))
    let eAny = Event.withValue(.any)
    let eNull = Event.withoutValue

    func testEquality() {
        XCTAssertEqual(e1, e1)
        XCTAssertEqual(e1, eAny)

        XCTAssertNotEqual(e1, e2)
        XCTAssertNotEqual(e1, eNull)
        XCTAssertNotEqual(eAny, eNull)
    }

    func testHashability() {
        let events = [eNull: 1, e1: 2]

        XCTAssertEqual(events[e1], 2)
        XCTAssertEqual(events[e2], nil)
        XCTAssertEqual(events[eAny], 2)
        XCTAssertEqual(events[eNull], 1)
    }
}
