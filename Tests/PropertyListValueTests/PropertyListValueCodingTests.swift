//
//  PropertyListValueCodingTests.swift
//  PropertyListTests
//

import Foundation
import Testing

import PropertyListValue

/// What ``PropertyListValue`` reads as when the bytes go through `PropertyListDecoder`.
///
/// Every case here wraps the value in a dictionary before encoding it. That is not incidental:
/// `PropertyListEncoder` refuses a top-level fragment, and wrapping also puts the value one level
/// down, where a decoder reaches it through a keyed container rather than the top-level one.
@Suite("PropertyListValue coding")
struct PropertyListValueCodingTests {
    private static let formats: [PropertyListSerialization.PropertyListFormat] = [.binary, .xml]

    private func encoded(
        _ value: PropertyListValue,
        as format: PropertyListSerialization.PropertyListFormat
    ) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = format

        return try encoder.encode(["value": value])
    }

    private func roundTripped(
        _ value: PropertyListValue,
        as format: PropertyListSerialization.PropertyListFormat = .binary
    ) throws -> PropertyListValue {
        let data = try encoded(value, as: format)
        let decoded = try PropertyListDecoder().decode([String: PropertyListValue].self, from: data)

        return try #require(decoded["value"])
    }

    // MARK: - Round Trip

    @Test(arguments: [
        PropertyListValue.string("Jane Doe"),
        .string(""),
        .data(Data([0x00, 0xFF])),
        .data(Data()),
        .date(Date(timeIntervalSinceReferenceDate: 0)),
        .bool(true),
        .bool(false),
        .integer(0),
        .integer(-1),
        .integer(Int64.min),
        .integer(Int64.max),
        .unsignedInteger(UInt64(Int64.max) + 1),
        .unsignedInteger(UInt64.max),
        .real(-1.5),
        .real(0.5),
        .array([]),
        .array([.integer(1), .string("two"), .bool(true), .real(3.5)]),
        .dictionary([:]),
        .dictionary(["name": .string("Jane Doe"), "age": .integer(30)]),
        .array([.dictionary(["tags": .array([.string("swift")])])]),
    ])
    func survivesARoundTripThroughABinaryPropertyList(_ value: PropertyListValue) throws {
        #expect(try roundTripped(value) == value)
    }

    @Test
    func survivesARoundTripThroughAnXMLPropertyList() throws {
        let value = PropertyListValue.dictionary([
            "name": .string("Jane Doe"),
            "age": .integer(30),
            "score": .real(1.5),
            "member": .bool(true),
            "joined": .date(Date(timeIntervalSinceReferenceDate: 0)),
            "avatar": .data(Data([0x01, 0x02])),
            "tags": .array([.string("swift"), .string("macOS")]),
        ])

        #expect(try roundTripped(value, as: .xml) == value)
    }

    // MARK: - Bool

    // The distinction `PropertyListDecoder` keeps and this cascade must not undo: `unwrapBool`
    // refuses a number, and the integer and real readers refuse a boolean, so neither order of
    // attempts can collapse the two.
    @Test
    func readsABooleanRatherThanTheNumberItWouldBridgeTo() throws {
        #expect(try roundTripped(.bool(true)) == .bool(true))
        #expect(try roundTripped(.bool(false)) == .bool(false))
        #expect(try roundTripped(.integer(1)) == .integer(1))
        #expect(try roundTripped(.integer(0)) == .integer(0))
    }

    // MARK: - Numbers

    // The documented normalization. `PropertyListDecoder` reads `<real>2</real>` as an `Int64`
    // exactly, and exposes nothing that says which tag was written, so `Int64` being attempted
    // first is what decides the answer.
    @Test
    func readsAWholeValuedRealAsAnInteger() throws {
        #expect(try roundTripped(.real(2)) == .integer(2))
        #expect(try roundTripped(.real(-3)) == .integer(-3))
    }

    // The other side of it: a real that no integer holds exactly reaches the `Double` attempt, so
    // the normalization is confined to the whole-valued ones.
    @Test
    func keepsARealThatNoIntegerHoldsExactly() throws {
        #expect(try roundTripped(.real(2.5)) == .real(2.5))
        #expect(try roundTripped(.real(.infinity)) == .real(.infinity))
        #expect(try roundTripped(.real(-.infinity)) == .real(-.infinity))
    }

    // NaN is checked apart from the others because it is not equal to itself, so `==` cannot ask.
    @Test
    func keepsANotANumberAsAReal() throws {
        let restored = try roundTripped(.real(.nan))
        let real = try #require(restored.real)

        #expect(real.isNaN)
    }

    // `UInt64` is attempted between `Int64` and `Double` rather than after them. A number above
    // `Int64.max` fails the first attempt, and a `Double` would take it next and round it.
    @Test
    func readsANumberWiderThanTheSignedRangeAsUnsigned() throws {
        #expect(try roundTripped(.unsignedInteger(UInt64(Int64.max) + 1))
            == .unsignedInteger(UInt64(Int64.max) + 1))
        #expect(try roundTripped(.unsignedInteger(.max)) == .unsignedInteger(.max))
    }

    // MARK: - Divergence From The `Any` Path

    // The one place the two ways in disagree, asserted rather than described so that a change to
    // either is a failing test rather than a surprise. `init(propertyList:)` asks
    // `CFNumberIsFloatType`, which a `Decoder` has no equivalent of.
    @Test
    func readsAWholeValuedRealDifferentlyFromThePropertyListPath() throws {
        let data = try encoded(.real(2), as: .binary)

        let throughDecodable = try PropertyListDecoder()
            .decode([String: PropertyListValue].self, from: data)["value"]
        let object = try unsafe PropertyListSerialization.propertyList(from: data, format: nil)
        let throughPropertyList = PropertyListValue(propertyList: object)?["value"]

        #expect(throughDecodable == .integer(2))
        #expect(throughPropertyList == .real(2))
        #expect(throughDecodable != throughPropertyList)
    }

    // Everything else agrees, which is what makes the case above the exception rather than a hint
    // that the two paths are unrelated.
    @Test(arguments: [
        PropertyListValue.string("Jane Doe"),
        .data(Data([0x00, 0xFF])),
        .date(Date(timeIntervalSinceReferenceDate: 0)),
        .bool(true),
        .integer(30),
        .unsignedInteger(UInt64(Int64.max) + 1),
        .real(2.5),
        .array([.integer(1), .string("two")]),
        .dictionary(["tags": .array([.string("swift")])]),
    ])
    func agreesWithThePropertyListPathEverywhereElse(_ value: PropertyListValue) throws {
        let data = try encoded(value, as: .binary)

        let throughDecodable = try PropertyListDecoder()
            .decode([String: PropertyListValue].self, from: data)["value"]
        let object = try unsafe PropertyListSerialization.propertyList(from: data, format: nil)
        let throughPropertyList = PropertyListValue(propertyList: object)?["value"]

        #expect(throughDecodable == throughPropertyList)
    }

    // MARK: - Encoding

    // The encoder's limit rather than this type's, kept as a test so the documentation on
    // `encode(to:)` stays true.
    @Test
    func refusesToEncodeAValueThatIsNotAContainerAtTheTop() {
        #expect(throws: (any Error).self) {
            try PropertyListEncoder().encode(PropertyListValue.string("Jane Doe"))
        }
    }

    @Test
    func encodesAContainerAtTheTop() throws {
        let value = PropertyListValue.dictionary(["name": .string("Jane Doe")])
        let data = try PropertyListEncoder().encode(value)

        #expect(try PropertyListDecoder().decode(PropertyListValue.self, from: data) == value)
    }
}
