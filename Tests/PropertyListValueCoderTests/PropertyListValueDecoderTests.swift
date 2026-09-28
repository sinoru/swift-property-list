//
//  PropertyListValueDecoderTests.swift
//  PropertyListValueCoderTests
//

import Foundation
import Testing
import PropertyListTestSupport

import PropertyListValue
import PropertyListValueCoder

@Suite("PropertyListValueDecoder")
struct PropertyListValueDecoderTests {
    private let decoder = PropertyListValueDecoder()

    // MARK: - Scalars

    @Test
    func decodesEachScalarFromItsOwnKind() throws {
        #expect(try decoder.decode(Bool.self, from: .bool(true)) == true)
        #expect(try decoder.decode(String.self, from: .string("hello")) == "hello")
        #expect(try decoder.decode(Int.self, from: .integer(42)) == 42)
        #expect(try decoder.decode(UInt64.self, from: .unsignedInteger(.max)) == UInt64.max)
        #expect(try decoder.decode(Double.self, from: .real(3.25)) == 3.25)
        #expect(try decoder.decode(Data.self, from: .data(Data([0x01]))) == Data([0x01]))
        #expect(
            try decoder.decode(Date.self, from: .date(Date(timeIntervalSinceReferenceDate: 5)))
                == Date(timeIntervalSinceReferenceDate: 5)
        )
    }

    // A `String`-backed enum is stored as a bare string, which is the top-level fragment
    // `PropertyListDecoder` refuses to be handed.
    @Test
    func decodesATopLevelFragment() throws {
        #expect(try decoder.decode(Theme.self, from: .string("dark")) == .dark)
    }

    // MARK: - Collections

    @Test
    func decodesAKeyedStructure() throws {
        let value = PropertyListValue.dictionary([
            "name": .string("Jane Doe"),
            "age": .integer(30),
            "tags": .array([.string("swift"), .string("macOS")]),
        ])

        #expect(
            try decoder.decode(Profile.self, from: value)
                == Profile(name: "Jane Doe", age: 30, tags: ["swift", "macOS"], nickname: nil)
        )
    }

    @Test
    func decodesNestedStructuresAndNativeKinds() throws {
        let date = Date(timeIntervalSinceReferenceDate: 1_000)
        let avatar = Data([0xDE, 0xAD])
        let value = PropertyListValue.dictionary([
            "profile": .dictionary([
                "name": .string("Jane Doe"),
                "age": .integer(30),
                "tags": .array([]),
                "nickname": .string("Janie"),
            ]),
            "updatedAt": .date(date),
            "avatar": .data(avatar),
        ])

        let record = try decoder.decode(Record.self, from: value)

        #expect(record.profile.nickname == "Janie")
        #expect(record.updatedAt == date)
        #expect(record.avatar == avatar)
    }

    @Test
    func decodesAnEmptyCollection() throws {
        #expect(try decoder.decode([Int].self, from: .array([])) == [])
        #expect(try decoder.decode([String: Int].self, from: .dictionary([:])) == [:])
    }

    // MARK: - Interoperability

    // Bytes Foundation wrote, read the way this package means them to be read: through
    // `init(data:)` into a tree, and out of the tree with this decoder. Each fixture leans on one
    // convention the two coders have to share — the sentinel for a `nil`, `super` for a superclass,
    // `Date` and `Data` stored as themselves — and reading it is what says the convention is in
    // fact shared, rather than merely asserted on both sides.
    @Test(arguments: [PropertyListSerialization.PropertyListFormat.binary, .xml])
    func readsWhatFoundationWrote(_ format: PropertyListSerialization.PropertyListFormat) throws {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = format

        let record = Record(
            profile: Profile(name: "Jane Doe", age: 30, tags: ["swift"], nickname: "Janie"),
            updatedAt: Date(timeIntervalSinceReferenceDate: 5),
            avatar: Data([0xDE, 0xAD])
        )
        let names = ["a", nil, "b"] as [String?]
        let car = Car(kind: "hatchback", doors: 5)

        #expect(
            try decoder.decode(Record.self, from: PropertyListValue(data: encoder.encode(record)))
                == record
        )
        #expect(
            try decoder.decode([String?].self, from: PropertyListValue(data: encoder.encode(names)))
                == names
        )

        let restored = try decoder.decode(
            Car.self,
            from: PropertyListValue(data: encoder.encode(car))
        )

        #expect(restored.kind == "hatchback")
        #expect(restored.doors == 5)
    }

    // MARK: - Optionals

    private struct Optionals: Codable, Equatable {
        var bool: Bool?
        var string: String?
        var int: Int?
        var uint8: UInt8?
        var double: Double?
        var float: Float?
        var date: Date?
        var data: Data?
        var value: PropertyListValue?
        var list: [Int]?

        static let keys = [
            "bool", "string", "int", "uint8", "double", "float", "date", "data", "value", "list",
        ]
    }

    // A synthesized `Decodable` reads an optional through `decodeIfPresent`, which asks
    // `contains`, then `decodeNil(forKey:)`, then `decode` — three answers a keyed container has
    // to keep straight for every kind it can be asked about. Absent and null both come out `nil`,
    // and present comes out as the value.
    @Test
    func readsAnAbsentOrNullOptionalOfEveryKindAsNil() throws {
        let nulls = PropertyListValue.dictionary(
            Dictionary(uniqueKeysWithValues: Optionals.keys.map { ($0, PropertyListValue.null) })
        )

        #expect(try decoder.decode(Optionals.self, from: [:]) == Optionals())
        #expect(try decoder.decode(Optionals.self, from: nulls) == Optionals())
    }

    @Test
    func readsAPresentOptionalOfEveryKind() throws {
        let date = Date(timeIntervalSinceReferenceDate: 5)
        let value: PropertyListValue = [
            "bool": true,
            "string": "a",
            "int": 1,
            "uint8": 2,
            "double": 3.5,
            "float": 4.5,
            "date": .date(date),
            "data": .data(Data([0x01])),
            "value": 6.5,
            "list": [7],
        ]

        #expect(
            try decoder.decode(Optionals.self, from: value) == Optionals(
                bool: true,
                string: "a",
                int: 1,
                uint8: 2,
                double: 3.5,
                float: 4.5,
                date: date,
                data: Data([0x01]),
                value: .real(6.5),
                list: [7]
            )
        )
    }

    // The unkeyed spelling of the same three answers: `decodeIfPresent` there asks `isAtEnd`, then
    // `decodeNil()`, then `decode`, and the index has to move exactly once whichever of them
    // answers. The trailing integer is what shows it did.
    @Test
    func readsANullElementOfEveryKindAsNil() throws {
        struct Probe: Decodable {
            let bool: Bool?
            let string: String?
            let int: Int?
            let double: Double?
            let float: Float?
            let date: Date?
            let data: Data?
            let value: PropertyListValue?
            let trailing: Int

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                bool = try container.decodeIfPresent(Bool.self)
                string = try container.decodeIfPresent(String.self)
                int = try container.decodeIfPresent(Int.self)
                double = try container.decodeIfPresent(Double.self)
                float = try container.decodeIfPresent(Float.self)
                date = try container.decodeIfPresent(Date.self)
                data = try container.decodeIfPresent(Data.self)
                value = try container.decodeIfPresent(PropertyListValue.self)
                trailing = try container.decode(Int.self)
            }
        }

        let nulls = try decoder.decode(
            Probe.self,
            from: .array([.null, .null, .null, .null, .null, .null, .null, .null, .integer(9)])
        )

        #expect(nulls.bool == nil)
        #expect(nulls.string == nil)
        #expect(nulls.int == nil)
        #expect(nulls.double == nil)
        #expect(nulls.float == nil)
        #expect(nulls.date == nil)
        #expect(nulls.data == nil)
        #expect(nulls.value == nil)
        #expect(nulls.trailing == 9)

        let date = Date(timeIntervalSinceReferenceDate: 5)
        let present = try decoder.decode(
            Probe.self,
            from: .array([
                .bool(true), .string("a"), .integer(1), .real(2.5), .real(3.5), .date(date),
                .data(Data([0x01])), .real(4.5), .integer(9),
            ])
        )

        #expect(present.bool == true)
        #expect(present.string == "a")
        #expect(present.int == 1)
        #expect(present.double == 2.5)
        #expect(present.float == 3.5)
        #expect(present.date == date)
        #expect(present.data == Data([0x01]))
        #expect(present.value == .real(4.5))
        #expect(present.trailing == 9)
    }

    // A `nil` with nothing around it. `Optional` decodes itself through a single value container,
    // so this is the top level reading the sentinel with no container in between.
    @Test
    func readsATopLevelSentinelAsNil() throws {
        #expect(try decoder.decode(String?.self, from: .null) == nil)
        #expect(try decoder.decode(String?.self, from: .string("a")) == "a")
        #expect(try decoder.decode(Int?.self, from: .integer(1)) == 1)
    }

    // MARK: - Reading a PropertyListValue back out

    // A value asked for as itself is handed back rather than decoded again. Its `Decodable`
    // conformance is written for a decoder reading bytes, where the only way to learn what a value
    // is, is to ask for it as something; run against this decoder those attempts meet the coercions
    // below, and the first one to answer wins. Every case here would come back as a different one.
    @Test(arguments: [
        PropertyListValue.integer(1),
        .integer(0),
        .real(3.7),
        .real(2),
        .bool(true),
        .bool(false),
        .string("Jane Doe"),
        .data(Data([0x00, 0xFF])),
        .date(Date(timeIntervalSinceReferenceDate: 0)),
        .unsignedInteger(UInt64(Int64.max) + 1),
        .array([.integer(1), .real(2)]),
        .dictionary(["flag": .integer(1), "score": .real(2)]),
    ])
    func handsAPropertyListValueBackUnchanged(_ value: PropertyListValue) throws {
        #expect(try decoder.decode(PropertyListValue.self, from: value) == value)
    }

    private struct Box: Codable, Equatable {
        var value: PropertyListValue
    }

    // The same, one level down, where the value arrives through a keyed container.
    @Test
    func handsANestedPropertyListValueBackUnchanged() throws {
        #expect(try decoder.decode(Box.self, from: .dictionary(["value": .integer(1)]))
            == Box(value: .integer(1)))
        #expect(try decoder.decode(Box.self, from: .dictionary(["value": .real(3.7)]))
            == Box(value: .real(3.7)))
    }

    @Test
    func survivesARoundTripThroughBothCoders() throws {
        let original = Box(value: .real(3.7))
        let encoded = try PropertyListValueEncoder().encode(original)

        #expect(try decoder.decode(Box.self, from: encoded) == original)
    }

    // MARK: - Numeric reading across kinds

    // The point of the whole exercise. `PropertyListDecoder` applies its rules only to what it can
    // reach from the top, and refuses a `<real>` asked for as an integer at all; these are the same
    // coercions the subscript documents, holding at a depth the old two-hop read never applied them.
    @Test
    func readsARealAsAnIntegerInsideACollection() throws {
        #expect(try decoder.decode([Int].self, from: .array([.real(3.7), .real(-3.7)])) == [3, -3])
    }

    // The top level reads a scalar without a decoder of its own, through the same unwraps a
    // container uses, and has to convert across kinds exactly as they do.
    @Test
    func readsNumbersAcrossKindsAtTheTop() throws {
        #expect(try decoder.decode(Int.self, from: .real(3.7)) == 3)
        #expect(try decoder.decode(Double.self, from: .integer(42)) == 42)
        #expect(try decoder.decode(Bool.self, from: .integer(1)) == true)
    }

    @Test
    func readsAnIntegerAsAFloatingPointInsideACollection() throws {
        #expect(try decoder.decode([Double].self, from: .array([.integer(42)])) == [42])
        #expect(try decoder.decode([Float].self, from: .array([.integer(42)])) == [42])
    }

    // `Float(exactly: 1.1)` is nil, which is exactly what `PropertyListDecoder` refuses on.
    @Test
    func readsADoubleAsAFloatWithoutRequiringItToBeExact() throws {
        #expect(try decoder.decode([Float].self, from: .array([.real(1.1)])) == [Float(1.1)])
    }

    @Test
    func readsABooleanFromTheTwoNumbersThatCanMeanOne() throws {
        #expect(try decoder.decode([Bool].self, from: .array([.integer(1), .integer(0)])) == [true, false])
        #expect(try decoder.decode([Bool].self, from: .array([.real(1), .real(0)])) == [true, false])
    }

    @Test
    func refusesABooleanReadFromAnyOtherNumber() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([Bool].self, from: .array([.integer(2)]))
        }
    }

    // A number too large for the type, and a NaN, both have to come back as an error rather than
    // trapping — `UserDefaults` is writable from outside the process, so both are reachable. The
    // same goes for a sign the type has no room for, in either direction, and for an infinity,
    // which truncates to itself and so is still too large.
    @Test
    func refusesANumberThatDoesNotFit() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int].self, from: .array([.real(1e300)]))
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int].self, from: .array([.real(.nan)]))
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int8].self, from: .array([.integer(300)]))
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode(UInt.self, from: .integer(-1))
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode(Int64.self, from: .unsignedInteger(.max))
        }
        #expect(throws: DecodingError.self) {
            try decoder.decode(Int.self, from: .real(.infinity))
        }
    }

    // NaN has no integer but is a perfectly good `Float`, and a `UInt64` too wide for a `Float` to
    // hold exactly is still read: `Float(UInt64.max)` is a rounding, not a refusal, which is what
    // "without requiring the result to be exact" means for the widest carrier as much as for `1.1`.
    @Test
    func readsAnyNumberAsAFloatingPointType() throws {
        #expect(try decoder.decode(Float.self, from: .real(.nan)).isNaN)
        #expect(try decoder.decode(Float.self, from: .unsignedInteger(.max)) == Float(UInt64.max))
        #expect(try decoder.decode(Double.self, from: .integer(.min)) == Double(Int64.min))
    }

    // Strict the way strings are. `Date` and `Data` have `Decodable` conformances that would read a
    // number and a byte sequence, and this decoder sets both aside to read the native case — which
    // means a number offered for a date is a mismatch here, not a date, and the error names what
    // was found.
    @Test
    func refusesADateOrDataReadFromAnyOtherCase() throws {
        let date = try #require(throws: DecodingError.self) {
            try decoder.decode(Date.self, from: .real(0))
        }
        let data = try #require(throws: DecodingError.self) {
            try decoder.decode(Data.self, from: .string("AP8="))
        }

        guard
            case .typeMismatch(_, let date) = date,
            case .typeMismatch(_, let data) = data
        else {
            Issue.record("expected two typeMismatch errors")
            return
        }

        #expect(date.debugDescription.contains("a real number"))
        #expect(data.debugDescription.contains("a string"))
    }

    // The other direction stays strict: a value of an unrelated kind is a mismatch, not a coercion.
    @Test
    func refusesAStringReadAsANumber() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([Int].self, from: .array([.string("42")]))
        }
    }

    @Test
    func refusesANumberReadAsAString() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([String].self, from: .array([.integer(42)]))
        }
    }

    // MARK: - Null

    @Test
    func readsTheNullSentinelAsNilInAnUnkeyedContainer() throws {
        let value = PropertyListValue.array([.string("a"), .string("$null"), .string("b")])

        #expect(try decoder.decode([String?].self, from: value) == ["a", nil, "b"])
    }

    @Test
    func readsTheNullSentinelAsNilUnderAKey() throws {
        let value = PropertyListValue.dictionary([
            "name": .string("Jane Doe"),
            "age": .integer(30),
            "tags": .array([]),
            "nickname": .string("$null"),
        ])

        #expect(try decoder.decode(Profile.self, from: value).nickname == nil)
    }

    @Test
    func refusesTheNullSentinelReadAsAValue() {
        #expect(throws: DecodingError.self) {
            try decoder.decode([String].self, from: .array([.string("$null")]))
        }
    }

    // MARK: - Errors

    @Test
    func reportsAMissingKey() throws {
        let value = PropertyListValue.dictionary(["name": .string("Jane Doe")])
        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: value)
        }

        guard case .keyNotFound(let key, _) = error else {
            Issue.record("expected keyNotFound, got \(error)")
            return
        }

        #expect(key.stringValue == "age")
    }

    @Test
    func reportsAMismatchAtTheTop() throws {
        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: .string("not a profile"))
        }

        guard case .typeMismatch(_, let context) = error else {
            Issue.record("expected typeMismatch, got \(error)")
            return
        }

        #expect(context.codingPath.isEmpty)
        #expect(context.debugDescription.contains("a string"))
    }

    // What the coding path is for: naming which element of which property refused, rather than just
    // saying the whole value did.
    @Test
    func reportsWhereInsideTheValueTheMismatchWas() throws {
        let value = PropertyListValue.dictionary([
            "name": .string("Jane Doe"),
            "age": .integer(30),
            "tags": .array([.string("swift"), .integer(2)]),
        ])
        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Profile.self, from: value)
        }

        guard case .typeMismatch(_, let context) = error else {
            Issue.record("expected typeMismatch, got \(error)")
            return
        }

        #expect(context.codingPath.map(\.stringValue) == ["tags", "Index 1"])
        #expect(context.codingPath.last?.intValue == 1)
    }

    // A scalar a generic caller reads — an `Array` or a `Dictionary` reading its elements — is
    // read without a decoder of its own, and still has to say where it was: under the key or at
    // the index that holds it, for each way the read can fail.
    @Test
    func reportsWhereAGenericallyReadScalarRefused() throws {
        let notFound = try #require(throws: DecodingError.self) {
            try decoder.decode([String: [Int]].self, from: ["a": [1, .string("$null")]])
        }
        let corrupted = try #require(throws: DecodingError.self) {
            try decoder.decode([String: [UInt8]].self, from: ["a": [1, 300]])
        }
        let mismatched = try #require(throws: DecodingError.self) {
            try decoder.decode([String: Bool].self, from: ["a": "yes"])
        }

        guard
            case .valueNotFound(_, let notFound) = notFound,
            case .dataCorrupted(let corrupted) = corrupted,
            case .typeMismatch(_, let mismatched) = mismatched
        else {
            Issue.record("expected valueNotFound, dataCorrupted and typeMismatch")
            return
        }

        #expect(notFound.codingPath.map(\.stringValue) == ["a", "Index 1"])
        #expect(corrupted.codingPath.map(\.stringValue) == ["a", "Index 1"])
        #expect(mismatched.codingPath.map(\.stringValue) == ["a"])
    }

    // The same three failures with nothing around the scalar: read with no decoder made for it,
    // each still reports the empty path a decoder at the top would have.
    @Test
    func reportsAScalarRefusedAtTheTop() throws {
        let notFound = try #require(throws: DecodingError.self) {
            try decoder.decode(Int.self, from: .string("$null"))
        }
        let corrupted = try #require(throws: DecodingError.self) {
            try decoder.decode(UInt8.self, from: .integer(300))
        }
        let mismatched = try #require(throws: DecodingError.self) {
            try decoder.decode(Int.self, from: .string("42"))
        }

        guard
            case .valueNotFound(_, let notFound) = notFound,
            case .dataCorrupted(let corrupted) = corrupted,
            case .typeMismatch(_, let mismatched) = mismatched
        else {
            Issue.record("expected valueNotFound, dataCorrupted and typeMismatch")
            return
        }

        #expect(notFound.codingPath.isEmpty)
        #expect(corrupted.codingPath.isEmpty)
        #expect(mismatched.codingPath.isEmpty)
    }

    @Test
    func reportsRunningOffTheEndOfAnUnkeyedContainer() throws {
        struct Pair: Decodable {
            let first: Int
            let second: Int

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                first = try container.decode(Int.self)
                second = try container.decode(Int.self)
            }
        }

        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Pair.self, from: .array([.integer(1)]))
        }

        guard case .valueNotFound(_, let context) = error else {
            Issue.record("expected valueNotFound, got \(error)")
            return
        }

        #expect(context.codingPath.map(\.stringValue) == ["Index 1"])
    }

    // `decodeNil(forKey:)` is a question about a value, so a key with none is `keyNotFound` rather
    // than `false` — which is what lets `decodeIfPresent` tell absent from null by asking
    // `contains` first. Foundation's containers answer the same way.
    @Test
    func reportsAMissingKeyAskedWhetherItIsNull() throws {
        struct Probe: Decodable {
            enum CodingKeys: String, CodingKey {
                case missing
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _ = try container.decodeNil(forKey: .missing)
            }
        }

        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Probe.self, from: [:])
        }

        guard case .keyNotFound(let key, _) = error else {
            Issue.record("expected keyNotFound, got \(error)")
            return
        }

        #expect(key.stringValue == "missing")
    }

    // And the unkeyed spelling of the same question, past the last element.
    @Test
    func reportsTheEndOfAnUnkeyedContainerAskedWhetherItIsNull() throws {
        struct Probe: Decodable {
            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                _ = try container.decodeNil()
            }
        }

        let error = try #require(throws: DecodingError.self) {
            try decoder.decode(Probe.self, from: [])
        }

        guard case .valueNotFound(_, let context) = error else {
            Issue.record("expected valueNotFound, got \(error)")
            return
        }

        #expect(context.codingPath.map(\.stringValue) == ["Index 0"])
    }

    // A container asked for under a key fails three ways, like a scalar does, and each names the
    // key: the value there is the wrong shape, there is no value there, or the value there is the
    // sentinel. Foundation's decoder gives the same three for the same input.
    @Test
    func reportsWhyANestedContainerWasRefused() throws {
        struct Outer: Decodable {
            enum CodingKeys: String, CodingKey {
                case inner
            }

            enum InnerKeys: String, CodingKey {
                case x
            }

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                _ = try container.nestedContainer(keyedBy: InnerKeys.self, forKey: .inner)
            }
        }

        let mismatched = try #require(throws: DecodingError.self) {
            try decoder.decode(Outer.self, from: ["inner": [1]])
        }
        let notFound = try #require(throws: DecodingError.self) {
            try decoder.decode(Outer.self, from: [:])
        }
        let null = try #require(throws: DecodingError.self) {
            try decoder.decode(Outer.self, from: ["inner": .null])
        }

        guard
            case .typeMismatch(_, let mismatched) = mismatched,
            case .keyNotFound(let key, _) = notFound,
            case .valueNotFound(_, let null) = null
        else {
            Issue.record("expected typeMismatch, keyNotFound and valueNotFound")
            return
        }

        #expect(mismatched.codingPath.map(\.stringValue) == ["inner"])
        #expect(key.stringValue == "inner")
        #expect(null.codingPath.map(\.stringValue) == ["inner"])
    }

    // MARK: - Container behaviour

    // What each container says its path is, asked from inside a decode rather than read off an
    // error — the only other place a path is visible. Foundation's coders are tested the same way.
    // A `superDecoder()` with no `super` key still answers, over the sentinel, and an unkeyed
    // `superDecoder()` takes the element at the index and moves past it.
    @Test
    func namesThePathOfEachContainer() throws {
        struct Probe: Decodable {
            enum CodingKeys: String, CodingKey {
                case list, dict, base
            }

            enum InnerKeys: String, CodingKey {
                case x
            }

            init(from decoder: any Decoder) throws {
                #expect(decoder.codingPath.isEmpty)

                let container = try decoder.container(keyedBy: CodingKeys.self)
                #expect(container.codingPath.isEmpty)

                var list = try container.nestedUnkeyedContainer(forKey: .list)
                #expect(list.codingPath.map(\.stringValue) == ["list"])

                let first = try list.nestedContainer(keyedBy: InnerKeys.self)
                #expect(first.codingPath.map(\.stringValue) == ["list", "Index 0"])

                let second = try list.superDecoder()
                #expect(second.codingPath.map(\.stringValue) == ["list", "Index 1"])
                #expect(try second.singleValueContainer().decode(Int.self) == 2)
                #expect(list.isAtEnd)

                let dict = try container.nestedContainer(keyedBy: InnerKeys.self, forKey: .dict)
                #expect(dict.codingPath.map(\.stringValue) == ["dict"])

                let base = try container.superDecoder(forKey: .base)
                #expect(base.codingPath.map(\.stringValue) == ["base"])
                #expect(try base.singleValueContainer().decode(String.self) == "widget")

                let absent = try container.superDecoder()
                #expect(absent.codingPath.map(\.stringValue) == ["super"])
                #expect(try absent.singleValueContainer().decodeNil())
            }
        }

        _ = try decoder.decode(
            Probe.self,
            from: ["list": [["x": 1], 2], "dict": ["x": 3], "base": "widget"]
        )
    }

    // `decodeNil()` consumes the element only when it says yes, so a caller that gets `false` reads
    // the same element as a value.
    @Test
    func leavesTheIndexAloneWhenAnElementIsNotNull() throws {
        struct Probe: Decodable {
            let wasNil: Bool
            let value: Int

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                wasNil = try container.decodeNil()
                value = try container.decode(Int.self)
            }
        }

        let probe = try decoder.decode(Probe.self, from: .array([.integer(7)]))

        #expect(probe.wasNil == false)
        #expect(probe.value == 7)
    }

    // A `Decodable` is allowed to try an element one way, catch the mismatch, and try it another.
    // Consuming on failure would hand the retry the element after it — or the end — so the index
    // moves only once a read has succeeded.
    @Test
    func leavesTheIndexAloneWhenAnElementFailsToDecode() throws {
        struct Retry: Decodable, Equatable {
            let values: [String]

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                var values = [String]()

                while !container.isAtEnd {
                    if let number = try? container.decode(Int.self) {
                        values.append("int:\(number)")
                    } else {
                        values.append("string:\(try container.decode(String.self))")
                    }
                }

                self.values = values
            }
        }

        let value = PropertyListValue.array([.string("a"), .integer(1), .string("b")])

        #expect(
            try decoder.decode(Retry.self, from: value).values == ["string:a", "int:1", "string:b"]
        )
    }

    // The same rule for a nested container: a failed request must not swallow the element.
    @Test
    func leavesTheIndexAloneWhenANestedContainerIsRefused() throws {
        struct Probe: Decodable {
            let recovered: String

            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                _ = try? container.nestedUnkeyedContainer()
                recovered = try container.decode(String.self)
            }
        }

        #expect(try decoder.decode(Probe.self, from: .array([.string("a")])).recovered == "a")
    }

    // An absent `super` stands in as null, not as an empty dictionary. A superclass that asks for a
    // container has to be told the value is missing rather than handed one with every key absent —
    // which is what `PropertyListDecoder` does with the same input.
    @Test
    func refusesASuperclassThatAsksForAContainerThatIsNotThere() {
        class Base: Codable {
            var kind: String?
        }

        final class Derived: Base {
            var extra = 0

            private enum CodingKeys: String, CodingKey {
                case extra
            }

            required init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                extra = try container.decode(Int.self, forKey: .extra)

                try super.init(from: container.superDecoder())
            }
        }

        #expect(throws: DecodingError.self) {
            try decoder.decode(Derived.self, from: .dictionary(["extra": .integer(9)]))
        }
    }

    @Test
    func reportsWhichKeysAKeyedContainerHas() throws {
        struct Keys: Decodable {
            let names: [String]

            init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: PropertyListCodingKeyStub.self)
                names = container.allKeys.map(\.stringValue).sorted()
            }
        }

        struct PropertyListCodingKeyStub: CodingKey {
            let stringValue: String
            var intValue: Int? { nil }

            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        let value = PropertyListValue.dictionary(["b": .integer(2), "a": .integer(1)])

        #expect(try decoder.decode(Keys.self, from: value).names == ["a", "b"])
    }

    // A class that inherits `Decodable` reads its superclass's half from `super`, and a superclass
    // that stored nothing leaves no key there to read.
    @Test
    func decodesThroughASuperDecoder() throws {
        class Base: Codable {
            var kind: String = ""
        }

        final class Derived: Base {
            var extra: Int = 0

            private enum CodingKeys: String, CodingKey {
                case extra
            }

            required init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                extra = try container.decode(Int.self, forKey: .extra)
                try super.init(from: container.superDecoder())
            }
        }

        let value = PropertyListValue.dictionary([
            "extra": .integer(9),
            "super": .dictionary(["kind": .string("widget")]),
        ])
        let derived = try decoder.decode(Derived.self, from: value)

        #expect(derived.extra == 9)
        #expect(derived.kind == "widget")
    }
}
