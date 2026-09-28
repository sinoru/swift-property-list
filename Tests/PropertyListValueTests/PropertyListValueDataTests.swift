//
//  PropertyListValueDataTests.swift
//  PropertyListTests
//

// Everything here reads through `propertyListValue(from:)`, which is gated the same way: where
// FoundationEssentials can be imported, it waits for the `ValueFoundation` trait.
#if ValueFoundation || !canImport(FoundationEssentials)
import Foundation
import Testing
import PropertyListTestSupport

import PropertyListValue

/// Reading whole property lists from their bytes.
@Suite("PropertyListValue from data")
struct PropertyListValueDataTests {
    private static let formats: [PropertyListSerialization.PropertyListFormat] = [.binary, .xml]

    private static let tree: PropertyListValue = [
        "name": "Jane Doe",
        "age": 30,
        "member": true,
        "tags": ["swift", "macOS"],
        "nested": ["depth": 2],
    ]

    /// A whole XML document around one element, with the declaration and DOCTYPE plist(5) shows.
    ///
    /// For what `PropertyListEncoder` will not write: a scalar at the top.
    private static func xml(_ element: String) -> Data {
        Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
                "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            \(element)
            </plist>
            """.utf8
        )
    }

    // MARK: - Reading

    @Test(arguments: formats)
    func readsATreeBackFromItsBytes(
        _ format: PropertyListSerialization.PropertyListFormat
    ) throws {
        let data = try Self.tree.serialized(as: format)

        #expect(try PropertyListSerialization.propertyListValue(from: data) == Self.tree)
    }

    @Test
    func readsThroughTheBytesOfAnArrayAtTheTop() throws {
        let value = PropertyListValue.array([.integer(1), .string("two")])
        let data = try value.serialized(as: .binary)

        #expect(try PropertyListSerialization.propertyListValue(from: data) == value)
    }

    // A property list need not be a container. plist(5) puts every basic type on the same footing
    // inside `<plist>`, and `PropertyListSerialization` hands a bare one back as itself. Written by
    // hand because `PropertyListEncoder` refuses to write a fragment.
    private static let scalarsAtTheTop: [(String, PropertyListValue)] = [
        ("<string>Jane Doe</string>", .string("Jane Doe")),
        ("<integer>7</integer>", .integer(7)),
        ("<real>2.5</real>", .real(2.5)),
        ("<true/>", .bool(true)),
        ("<date>2001-01-01T00:00:00Z</date>", .date(Date(timeIntervalSinceReferenceDate: 0))),
        ("<data>AP8=</data>", .data(Data([0x00, 0xFF]))),
    ]

    @Test(arguments: scalarsAtTheTop)
    func readsAScalarAtTheTop(_ element: String, _ expected: PropertyListValue) throws {
        let value = try PropertyListSerialization.propertyListValue(from: Self.xml(element))

        #expect(value == expected)
    }

    // The third format, which `PropertyListSerialization` falls back to when the bytes are neither
    // binary nor XML. It has strings, data, arrays and dictionaries and nothing else, so what looks
    // like a number arrives as a string: the reader has no way to know `30` was meant as one.
    @Test
    func readsAnOpenStepPropertyList() throws {
        let data = Data(
            #"{ name = "Jane Doe"; age = 30; tags = (swift, macOS); avatar = <00ff>; }"#.utf8
        )

        #expect(
            try PropertyListSerialization.propertyListValue(from: data) == [
                "name": "Jane Doe",
                "age": "30",
                "tags": ["swift", "macOS"],
                "avatar": .data(Data([0x00, 0xFF])),
            ]
        )
    }

    // MARK: - Faithfulness

    // The reason this exists next to `init(from:)` rather than instead of it. Both read the same
    // bytes; only this one can ask which tag was written.
    @Test
    func keepsAWholeValuedRealThatDecodingWouldNormalize() throws {
        let data = try PropertyListValue.dictionary(["value": .real(2)]).serialized(as: .binary)

        let throughData = try PropertyListSerialization.propertyListValue(from: data)
        let throughDecodable = try PropertyListDecoder().decode(PropertyListValue.self, from: data)

        #expect(throughData["value"] == .real(2))
        #expect(throughDecodable["value"] == .integer(2))
    }

    @Test
    func keepsTheBooleanAndNumericCasesApart() throws {
        let data = try PropertyListValue.dictionary(["flag": .bool(true), "count": .integer(1)])
            .serialized(as: .binary)
        let value = try PropertyListSerialization.propertyListValue(from: data)

        #expect(value["flag"] == .bool(true))
        #expect(value["count"] == .integer(1))
    }

    // Both formats, because the wide integer is where they differ most: binary stores it in 16
    // bytes, and XML as the decimal `9223372036854775808`, which the parser has to hold in a
    // 128-bit number to keep at all.
    @Test(arguments: formats)
    func readsTheLeafCasesTheFormatCarries(
        _ format: PropertyListSerialization.PropertyListFormat
    ) throws {
        let value = PropertyListValue.dictionary([
            "data": .data(Data([0x00, 0xFF])),
            "date": .date(Date(timeIntervalSinceReferenceDate: 0)),
            "wide": .unsignedInteger(UInt64(Int64.max) + 1),
            "real": .real(2.5),
        ])
        let data = try value.serialized(as: format)

        #expect(try PropertyListSerialization.propertyListValue(from: data) == value)
    }

    // The three values `<real>` spells in words rather than digits. NaN is checked apart from the
    // other two because it is not equal to itself.
    @Test(arguments: formats)
    func readsTheRealsTheFormatSpellsInWords(
        _ format: PropertyListSerialization.PropertyListFormat
    ) throws {
        let value = PropertyListValue.dictionary([
            "up": .real(.infinity),
            "down": .real(-.infinity),
            "nan": .real(.nan),
        ])
        let restored = try PropertyListSerialization.propertyListValue(
            from: value.serialized(as: format)
        )

        #expect(restored["up"] == .real(.infinity))
        #expect(restored["down"] == .real(-.infinity))
        #expect(restored["nan"]?.real?.isNaN == true)
    }

    // MARK: - Numbers

    // `PropertyListEncoder` writes every `UInt64` in the 16-byte form whatever the value, and a
    // negative `Int64` in the 8-byte form whose top bit is the sign. Neither width says which case
    // a number is: `7` is an integer however many bytes it took, and `-1` is one however many bits
    // were set. What decides is the value, tried against `Int64` first.
    @Test
    func readsANumberByItsValueRatherThanItsWidth() throws {
        struct Widths: Encodable {
            let narrow = UInt64(7)
            let wide = UInt64.max
            let negative = Int64(-1)
        }

        let value = try PropertyListSerialization.propertyListValue(
            from: PropertyListEncoder().encode(Widths())
        )

        #expect(value["narrow"] == .integer(7))
        #expect(value["wide"] == .unsignedInteger(.max))
        #expect(value["negative"] == .integer(-1))
    }

    // `Float` is the one number the binary format stores in a width of its own — four bytes — and
    // XML writes with the digits of the `Double` it widens to. Either way it arrives as a
    // floating-point `NSNumber` that is not a `Double`, which is the case the `objCType` `f` branch
    // away from Darwin exists for. Widening a `Float` to `Double` is exact, so the answer is the
    // same as if the caller had widened it.
    @Test(arguments: formats)
    func readsAFloatAsAReal(_ format: PropertyListSerialization.PropertyListFormat) throws {
        struct Narrow: Encodable {
            let value = Float(0.1)
        }

        let encoder = PropertyListEncoder()
        encoder.outputFormat = format
        let data = try encoder.encode(Narrow())

        let value = try PropertyListSerialization.propertyListValue(from: data)

        #expect(value == ["value": .real(Double(Float(0.1)))])
    }

    // MARK: - Rejection

    @Test
    func throwsForBytesThatAreNotAPropertyList() {
        #expect(throws: (any Error).self) {
            try PropertyListSerialization.propertyListValue(from: Data("not a property list".utf8))
        }
    }

    @Test
    func throwsForEmptyBytes() {
        #expect(throws: (any Error).self) {
            try PropertyListSerialization.propertyListValue(from: Data())
        }
    }

    // The one thing a property list is allowed to hold that no case here carries, and the reason
    // the documentation on `propertyListValue(from:)` names `DecodingError`: an `NSKeyedArchiver`
    // archive is a property list whose object table is stitched together with
    // `CFKeyedArchiverUID`s. `PropertyListSerialization` reads it without complaint; refusing it is
    // this package's job.
    //
    // Not on WASI, where `NSKeyedArchiver` hands back no bytes at all, so there is no archive to
    // refuse — what fails there is the fixture, not the reading.
    #if !os(WASI)
    @Test
    func throwsForAnArchiveHoldingAKeyedArchiverUID() throws {
        let archive = try NSKeyedArchiver.archivedData(
            withRootObject: ["Jane Doe"] as NSArray,
            requiringSecureCoding: false
        )

        #expect(throws: DecodingError.self) {
            try PropertyListSerialization.propertyListValue(from: archive)
        }
    }
    #endif

    // The binary format has a marker for null, which `PropertyListSerialization` reads as `NSNull`.
    // `CFPropertyListIsValid` refuses it, so nothing Foundation writes contains one — but anyone
    // can write the bytes, and here they are: `bplist00`, one object that is the null marker, the
    // offset table pointing at it, and the trailer saying so.
    @Test
    func throwsForABinaryPropertyListHoldingANull() {
        let data = Data(
            Array("bplist00".utf8) + [0x00] + [0x08]
                + [UInt8](repeating: 0, count: 6) + [1, 1]
                + [0, 0, 0, 0, 0, 0, 0, 1]
                + [0, 0, 0, 0, 0, 0, 0, 0]
                + [0, 0, 0, 0, 0, 0, 0, 9]
        )

        #expect(throws: DecodingError.self) {
            try PropertyListSerialization.propertyListValue(from: data)
        }
    }
}
#endif
