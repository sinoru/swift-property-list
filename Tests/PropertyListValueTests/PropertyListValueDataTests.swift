//
//  PropertyListValueDataTests.swift
//  PropertyListTests
//

import Foundation
import Testing

import PropertyListValue

/// Reading whole property lists from their bytes.
@Suite("PropertyListValue from data")
struct PropertyListValueDataTests {
    private static let tree: PropertyListValue = [
        "name": "Jane Doe",
        "age": 30,
        "member": true,
        "tags": ["swift", "macOS"],
        "nested": ["depth": 2],
    ]

    private func encoded(
        _ value: PropertyListValue,
        as format: PropertyListSerialization.PropertyListFormat
    ) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = format

        return try encoder.encode(value)
    }

    // MARK: - Reading

    @Test(arguments: [
        PropertyListSerialization.PropertyListFormat.binary,
        .xml,
    ])
    func readsATreeBackFromItsBytes(
        _ format: PropertyListSerialization.PropertyListFormat
    ) throws {
        let data = try encoded(Self.tree, as: format)

        #expect(try PropertyListValue(data: data) == Self.tree)
    }

    @Test
    func readsThroughTheBytesOfAnArrayAtTheTop() throws {
        let value = PropertyListValue.array([.integer(1), .string("two")])
        let data = try encoded(value, as: .binary)

        #expect(try PropertyListValue(data: data) == value)
    }

    // MARK: - Faithfulness

    // The reason this exists next to `init(from:)` rather than instead of it. Both read the same
    // bytes; only this one can ask which tag was written.
    @Test
    func keepsAWholeValuedRealThatDecodingWouldNormalize() throws {
        let data = try encoded(["value": .real(2)], as: .binary)

        let throughData = try PropertyListValue(data: data)
        let throughDecodable = try PropertyListDecoder().decode(PropertyListValue.self, from: data)

        #expect(throughData["value"] == .real(2))
        #expect(throughDecodable["value"] == .integer(2))
    }

    @Test
    func keepsTheBooleanAndNumericCasesApart() throws {
        let data = try encoded(["flag": .bool(true), "count": .integer(1)], as: .binary)
        let value = try PropertyListValue(data: data)

        #expect(value["flag"] == .bool(true))
        #expect(value["count"] == .integer(1))
    }

    @Test
    func readsTheLeafCasesTheFormatCarries() throws {
        let value = PropertyListValue.dictionary([
            "data": .data(Data([0x00, 0xFF])),
            "date": .date(Date(timeIntervalSinceReferenceDate: 0)),
            "wide": .unsignedInteger(UInt64(Int64.max) + 1),
            "real": .real(2.5),
        ])
        let data = try encoded(value, as: .binary)

        #expect(try PropertyListValue(data: data) == value)
    }

    // MARK: - Rejection

    @Test
    func throwsForBytesThatAreNotAPropertyList() {
        #expect(throws: (any Error).self) {
            try PropertyListValue(data: Data("not a property list".utf8))
        }
    }

    @Test
    func throwsForEmptyBytes() {
        #expect(throws: (any Error).self) {
            try PropertyListValue(data: Data())
        }
    }
}
