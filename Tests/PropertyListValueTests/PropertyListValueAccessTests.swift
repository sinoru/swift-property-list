//
//  PropertyListValueAccessTests.swift
//  PropertyListTests
//

import Foundation
import Testing

import PropertyListValue

/// Reading a tree whose shape the caller did not write, which is the reason to hold a
/// ``PropertyListValue`` rather than a `Decodable` type.
@Suite("PropertyListValue access")
struct PropertyListValueAccessTests {
    private static let archive = PropertyListValue.dictionary([
        "WebSubresources": .array([
            .dictionary([
                "WebResourceURL": .string("https://example.com/a.png"),
                "WebResourceMIMEType": .string("image/png"),
                "WebResourceData": .data(Data([0x89, 0x50])),
            ]),
        ]),
        "WebMainResource": .dictionary(["WebResourceFrameName": .string("")]),
    ])

    // MARK: - Values

    @Test
    func answersForTheCaseItHoldsAndNoOther() {
        #expect(PropertyListValue.string("a").string == "a")
        #expect(PropertyListValue.data(Data([0x01])).data == Data([0x01]))
        #expect(PropertyListValue.date(.distantPast).date == .distantPast)
        #expect(PropertyListValue.bool(true).bool == true)
        #expect(PropertyListValue.integer(1).integer == 1)
        #expect(PropertyListValue.unsignedInteger(.max).unsignedInteger == .max)
        #expect(PropertyListValue.real(1.5).real == 1.5)
        #expect(PropertyListValue.array([.integer(1)]).array == [.integer(1)])
        #expect(PropertyListValue.dictionary(["a": .integer(1)]).dictionary == ["a": .integer(1)])
    }

    @Test
    func answersNilForEveryOtherCase() {
        let value = PropertyListValue.string("a")

        #expect(value.dictionary == nil)
        #expect(value.array == nil)
        #expect(value.data == nil)
        #expect(value.date == nil)
        #expect(value.bool == nil)
        #expect(value.integer == nil)
        #expect(value.unsignedInteger == nil)
        #expect(value.real == nil)
    }

    // Each accessor asks which case this is, not which Swift type the number could be read as.
    // A caller wanting a number however it was written asks more than one and converts.
    @Test
    func doesNotConvertBetweenTheNumericCases() {
        #expect(PropertyListValue.real(2).integer == nil)
        #expect(PropertyListValue.integer(2).real == nil)
        #expect(PropertyListValue.integer(2).unsignedInteger == nil)
        #expect(PropertyListValue.unsignedInteger(2).integer == nil)
        #expect(PropertyListValue.integer(1).bool == nil)
        #expect(PropertyListValue.bool(true).integer == nil)
    }

    // MARK: - Key Subscript

    @Test
    func readsThroughAKeyedTree() {
        let subresource = Self.archive["WebSubresources"]?[0]

        #expect(subresource?["WebResourceURL"]?.string == "https://example.com/a.png")
        #expect(subresource?["WebResourceData"]?.data == Data([0x89, 0x50]))
    }

    // A wrong shape and a missing key are one answer on purpose: a caller walking an unfamiliar
    // tree is asking whether what it wants is there.
    @Test
    func answersNilForAMissingKeyAndForAValueThatIsNotADictionary() {
        #expect(Self.archive["WebSubframeArchives"] == nil)
        #expect(PropertyListValue.string("a")["WebResourceURL"] == nil)
    }

    @Test
    func fallsBackToTheDefaultWhenThereIsNoValue() {
        #expect(Self.archive["WebSubframeArchives", default: .array([])] == .array([]))
        #expect(Self.archive["WebMainResource", default: .array([])].dictionary != nil)
    }

    @Test
    func addsAndReplacesThroughAKey() {
        var value = PropertyListValue.dictionary(["a": .integer(1)])

        value["b"] = .string("two")
        #expect(value == .dictionary(["a": .integer(1), "b": .string("two")]))

        value["a"] = .integer(2)
        #expect(value == .dictionary(["a": .integer(2), "b": .string("two")]))
    }

    // Absence is the only thing a property list dictionary can say about a value it does not hold,
    // the format having no null, so assigning `nil` removes the key.
    @Test
    func removesTheKeyWhenAssignedNil() {
        var value = PropertyListValue.dictionary(["a": .integer(1), "b": .string("two")])

        value["a"] = nil

        #expect(value == .dictionary(["b": .string("two")]))
    }

    @Test
    func becomesADictionaryWhenAssignedThroughSomethingElse() {
        var value = PropertyListValue.string("a")

        value["b"] = .integer(1)

        #expect(value == .dictionary(["b": .integer(1)]))
    }

    // MARK: - Index Subscript

    @Test
    func readsThroughAnIndex() {
        let value = PropertyListValue.array([.integer(1), .string("two")])

        #expect(value[0] == .integer(1))
        #expect(value[1] == .string("two"))
    }

    // Bounds-checked rather than trapping: an index into a tree the caller has not seen the shape
    // of is a question, and out of range is an answer to it.
    @Test
    func answersNilForAnIndexOutsideTheArrayAndForAValueThatIsNotOne() {
        let value = PropertyListValue.array([.integer(1)])

        #expect(value[1] == nil)
        #expect(value[-1] == nil)
        #expect(PropertyListValue.dictionary(["a": .integer(1)])[0] == nil)
    }

    // MARK: - Literals

    @Test
    func buildsFromLiterals() {
        let value: PropertyListValue = [
            "name": "Jane Doe",
            "age": 30,
            "score": 1.5,
            "member": true,
            "tags": ["swift", "macOS"],
        ]

        #expect(value["name"] == .string("Jane Doe"))
        #expect(value["age"] == .integer(30))
        #expect(value["score"] == .real(1.5))
        #expect(value["member"] == .bool(true))
        #expect(value["tags"] == .array([.string("swift"), .string("macOS")]))
    }

    // A boolean literal is a boolean rather than the number it would bridge to, the same
    // distinction the type keeps everywhere else.
    @Test
    func buildsABooleanLiteralAsABoolean() {
        let value: PropertyListValue = true

        #expect(value == .bool(true))
        #expect(value != .integer(1))
    }

    // MARK: - Null

    // The sentinel is the one string Foundation writes a `nil` as, and nothing else answers to it:
    // not another string, not an empty one, and not a container that happens to hold it.
    @Test
    func answersForTheSentinelAndNothingElse() {
        #expect(PropertyListValue.string("$null").isNull)

        #expect(!PropertyListValue.string("null").isNull)
        #expect(!PropertyListValue.string("").isNull)
        #expect(!PropertyListValue.data(Data("$null".utf8)).isNull)
        #expect(!PropertyListValue.array([.string("$null")]).isNull)
        #expect(!PropertyListValue.dictionary(["$null": .string("$null")]).isNull)
    }
}
