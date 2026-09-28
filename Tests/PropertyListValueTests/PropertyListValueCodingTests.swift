//
//  PropertyListValueCodingTests.swift
//  PropertyListTests
//

import Foundation
import Testing
import PropertyListTestSupport

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
        try PropertyListValue.dictionary(["value": value]).serialized(as: format)
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

    private static let roundTrippable: [PropertyListValue] = [
        .string("Jane Doe"),
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
    ]

    // Both formats, since they store almost every case differently and the reader below sees
    // neither: it sees what `PropertyListDecoder` made of the bytes.
    @Test(arguments: roundTrippable, formats)
    func survivesARoundTripThroughAPropertyList(
        _ value: PropertyListValue,
        _ format: PropertyListSerialization.PropertyListFormat
    ) throws {
        #expect(try roundTripped(value, as: format) == value)
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

    // `PropertyListEncoder` writes a `UInt64` in 16 bytes whatever it holds and a `Float` in four,
    // and `PropertyListDecoder` reads each back through `T(exactly:)`. So the `Int64` attempt takes
    // a narrow unsigned value, and the `Double` attempt takes a `Float` widened without loss — the
    // same two answers `init(propertyList:)` gives for the same bytes, reached a different way.
    //
    // Only where that bridge is compiled in, which away from Apple platforms is behind the
    // `ValueFoundation` trait.
    #if ValueFoundation || !canImport(FoundationEssentials)
    @Test
    func readsANarrowUnsignedIntegerAndAFloatAsThePropertyListPathDoes() throws {
        struct Widths: Encodable {
            let narrow = UInt64(7)
            let real = Float(0.1)
        }

        let data = try PropertyListEncoder().encode(Widths())
        let throughDecodable = try PropertyListDecoder().decode(PropertyListValue.self, from: data)
        let throughData = try PropertyListSerialization.propertyListValue(from: data)

        #expect(throughDecodable == ["narrow": .integer(7), "real": .real(Double(Float(0.1)))])
        #expect(throughDecodable == throughData)
    }
    #endif

    // MARK: - Null

    // The sentinel is a string, but Foundation's scanners fold it into a null while they are still
    // reading bytes: `decodeNil()` answers true for it and every other read refuses it. Asking
    // about null before anything else is therefore the only way to read a tree that holds one —
    // and that is any tree the coder in this package wrote a `nil` into.
    @Test(arguments: formats)
    func readsTheNullSentinelBack(_ format: PropertyListSerialization.PropertyListFormat) throws {
        let value = PropertyListValue.array([.string("a"), .null, .string("b")])

        #expect(try roundTripped(value, as: format) == value)
    }

    // The same bytes as Foundation's own encoder writes them, since the point of sharing the
    // sentinel is reading what `PropertyListEncoder` wrote.
    @Test
    func readsANilThatFoundationWroteAsTheSentinel() throws {
        let data = try PropertyListEncoder().encode(["value": ["a", nil] as [String?]])
        let decoded = try PropertyListDecoder().decode([String: PropertyListValue].self, from: data)

        #expect(decoded["value"] == .array([.string("a"), .null]))
    }

    // MARK: - Divergence From The `Any` Path

    // Only where the `Any` path is compiled in, which away from Apple platforms is behind the
    // `ValueFoundation` trait.
    #if ValueFoundation || !canImport(FoundationEssentials)
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
    #endif

    // MARK: - Another Decoder

    // The reason the conformance exists rather than `propertyListValue(from:)` alone: a `Decoder`
    // that is not Foundation's property list one. The order of attempts is the same, and so is what
    // it settles — JSON's `Int64` reader takes a whole-valued `2.0` just as the property list one
    // does, so the real is normalized here too.
    @Test
    func readsFromADecoderThatIsNotAPropertyListOne() throws {
        let json = Data(
            #"""
            {"name": "Jane Doe", "age": 30, "score": 2.0, "member": true, "tags": ["swift"],
             "wide": 18446744073709551615}
            """#.utf8
        )

        #expect(
            try JSONDecoder().decode(PropertyListValue.self, from: json) == [
                "name": "Jane Doe",
                "age": 30,
                "score": 2,
                "member": true,
                "tags": ["swift"],
                "wide": .unsignedInteger(.max),
            ]
        )
    }

    // JSON has a null of its own, and it reads as the sentinel a property list would have stood in
    // its place: the value an encoder in this package writes for a `nil`.
    @Test
    func readsAJSONNullAsTheSentinel() throws {
        let json = Data(#"{"nickname": null}"#.utf8)

        #expect(try JSONDecoder().decode(PropertyListValue.self, from: json) == ["nickname": .null])
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
