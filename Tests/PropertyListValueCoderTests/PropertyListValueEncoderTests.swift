//
//  PropertyListValueEncoderTests.swift
//  PropertyListValueCoderTests
//

import Foundation
import Testing
import PropertyListTestSupport

import PropertyListValue
import PropertyListValueCoder

@Suite("PropertyListValueEncoder")
struct PropertyListValueEncoderTests {
    private let encoder = PropertyListValueEncoder()
    private let decoder = PropertyListValueDecoder()

    // MARK: - Scalars

    @Test
    func writesEachScalarInTheShapeThePropertyListHas() throws {
        #expect(try encoder.encode(true) == .bool(true))
        #expect(try encoder.encode("hello") == .string("hello"))
        #expect(try encoder.encode(42) == .integer(42))
        #expect(try encoder.encode(3.25) == .real(3.25))
        #expect(try encoder.encode(Float(0.5)) == .real(0.5))
        #expect(try encoder.encode(Data([0x01])) == .data(Data([0x01])))
        #expect(
            try encoder.encode(Date(timeIntervalSinceReferenceDate: 5))
                == .date(Date(timeIntervalSinceReferenceDate: 5))
        )
    }

    // `<true/>` rather than `<integer>1</integer>`, which is what keeps `defaults(1)` printing it as
    // a boolean and what lets a reader tell the two apart at all.
    @Test
    func writesABooleanAsABooleanRatherThanANumber() throws {
        #expect(try encoder.encode(true) == .bool(true))
        #expect(try encoder.encode(1) == .integer(1))
    }

    // One spelling per number: the unsigned case carries only what the signed one cannot.
    @Test
    func writesAnUnsignedValueAsAnIntegerWhileItFits() throws {
        #expect(try encoder.encode(UInt64(7)) == .integer(7))
        #expect(try encoder.encode(UInt64(Int64.max)) == .integer(Int64.max))
        #expect(try encoder.encode(UInt64.max) == .unsignedInteger(UInt64.max))
        #expect(try encoder.encode(Int64.min) == .integer(Int64.min))
    }

    // What `PropertyListEncoder` refuses, and the reason the old write path wrapped every value in a
    // single-element array and unwrapped the result again.
    @Test
    func writesATopLevelFragment() throws {
        #expect(try encoder.encode(Theme.dark) == .string("dark"))
        #expect(try encoder.encode(7) == .integer(7))
    }

    // MARK: - Collections

    @Test
    func writesAStructureAsADictionary() throws {
        let value = try encoder.encode(Profile(name: "Jane Doe", age: 30, tags: ["swift"], nickname: nil))

        #expect(
            value == .dictionary([
                "name": .string("Jane Doe"),
                "age": .integer(30),
                "tags": .array([.string("swift")]),
            ])
        )
    }

    // A synthesized `Encodable` calls `encodeIfPresent`, which leaves the key out rather than
    // writing the sentinel — so an absent value stays absent in what `defaults(1)` prints.
    @Test
    func leavesAnAbsentPropertyOutRatherThanWritingTheSentinel() throws {
        let value = try encoder.encode(Profile(name: "a", age: 1, tags: [], nickname: nil))

        guard case .dictionary(let dictionary) = value else {
            Issue.record("expected a dictionary, got \(value)")
            return
        }

        #expect(dictionary["nickname"] == nil)
    }

    // An array has no way to leave a hole, so the sentinel is what holds the position.
    @Test
    func writesTheSentinelForANilElement() throws {
        let value = try encoder.encode(["a", nil, "b"] as [String?])

        #expect(value == .array([.string("a"), .string("$null"), .string("b")]))
    }

    @Test
    func writesNestedCollections() throws {
        let value = try encoder.encode(["outer": ["inner": [1, 2]]])

        #expect(
            value == .dictionary([
                "outer": .dictionary(["inner": .array([.integer(1), .integer(2)])]),
            ])
        )
    }

    // The contracts `PropertyListFuture` exists for, which nothing a synthesized `Codable` writes
    // ever reaches: a type that asks for a nested container writes into the parent's tree, and
    // asking twice for the same key gets the container it already had rather than a fresh one that
    // discards what was written.
    @Test
    func writesIntoANestedContainerAskedForTwice() throws {
        struct Twice: Encodable {
            enum Outer: String, CodingKey {
                case inner
            }

            enum Inner: String, CodingKey {
                case x, y
            }

            func encode(to encoder: any Encoder) throws {
                var outer = encoder.container(keyedBy: Outer.self)

                var first = outer.nestedContainer(keyedBy: Inner.self, forKey: .inner)
                try first.encode(1, forKey: .x)

                var second = outer.nestedContainer(keyedBy: Inner.self, forKey: .inner)
                try second.encode(2, forKey: .y)
            }
        }

        #expect(
            try encoder.encode(Twice()) == .dictionary([
                "inner": .dictionary(["x": .integer(1), "y": .integer(2)]),
            ])
        )
    }

    @Test
    func writesIntoANestedUnkeyedContainer() throws {
        struct Nested: Encodable {
            enum Outer: String, CodingKey {
                case list
            }

            func encode(to encoder: any Encoder) throws {
                var outer = encoder.container(keyedBy: Outer.self)
                var list = outer.nestedUnkeyedContainer(forKey: .list)
                try list.encode(1)

                var inner = list.nestedUnkeyedContainer()
                try inner.encode(2)

                try list.encode(3)
            }
        }

        #expect(
            try encoder.encode(Nested()) == .dictionary([
                "list": .array([.integer(1), .array([.integer(2)]), .integer(3)]),
            ])
        )
    }

    // `superEncoder()` takes its position when it is made and fills it when it is released, so what
    // the caller encodes in between lands after it rather than in front of it.
    @Test
    func keepsThePositionAnUnkeyedSuperEncoderReserved() throws {
        struct Ordered: Encodable {
            func encode(to encoder: any Encoder) throws {
                var container = encoder.unkeyedContainer()
                try container.encode(0)

                let reserved = container.superEncoder()
                try container.encode(2)

                var single = reserved.singleValueContainer()
                try single.encode(1)
            }
        }

        #expect(try encoder.encode(Ordered()) == .array([.integer(0), .integer(1), .integer(2)]))
    }

    // Two of them at once each hold a position of their own. Remembering `count` instead would give
    // both the same one, and the order of the result would then depend on the order they happen to
    // be released in — which is reverse of creation for locals, and creation order once the caller
    // clears them itself, as here.
    @Test
    func keepsTwoUnkeyedSuperEncodersApart() throws {
        struct TwoSupers: Encodable {
            func encode(to encoder: any Encoder) throws {
                var container = encoder.unkeyedContainer()

                var first: (any Encoder)? = container.superEncoder()
                var second: (any Encoder)? = container.superEncoder()

                // Scoped so that nothing but the optionals holds either encoder by the time they
                // are cleared: `singleValueContainer()` hands back the encoder itself, so a
                // container left in scope would keep it alive and release it in reverse.
                if let first {
                    var single = first.singleValueContainer()
                    try single.encode(1)
                }
                if let second {
                    var single = second.singleValueContainer()
                    try single.encode(2)
                }

                first = nil
                second = nil
            }
        }

        #expect(try encoder.encode(TwoSupers()) == .array([.integer(1), .integer(2)]))
    }

    // A reservation is visible to the container that made it, so an element encoded afterwards is
    // told the right position when it has to name one.
    @Test
    func countsAReservedPositionWhileItIsOutstanding() throws {
        struct Counting: Encodable {
            func encode(to encoder: any Encoder) throws {
                var container = encoder.unkeyedContainer()

                let reserved = container.superEncoder()
                #expect(container.count == 1)

                try container.encode(2)
                #expect(container.count == 2)

                var single = reserved.singleValueContainer()
                try single.encode(1)
            }
        }

        #expect(try encoder.encode(Counting()) == .array([.integer(1), .integer(2)]))
    }

    @Test
    func writesAnEmptyCollection() throws {
        #expect(try encoder.encode([Int]()) == .array([]))
        #expect(try encoder.encode([String: Int]()) == .dictionary([:]))
    }

    // The last value written under a key is the one kept, the way it is in a dictionary — which is
    // also what Foundation's encoder does with the same two calls.
    @Test
    func keepsTheLastValueWrittenUnderAKey() throws {
        struct Twice: Encodable {
            enum CodingKeys: String, CodingKey {
                case k
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(1, forKey: .k)
                try container.encode("two", forKey: .k)
            }
        }

        #expect(try encoder.encode(Twice()) == ["k": "two"])
    }

    // What each container says its path is, asked from inside an encode rather than read off an
    // error. Foundation's coders are tested the same way. Every container here is left empty on
    // purpose, so what comes out is the shape the asks alone produced — including the empty
    // dictionary a `superEncoder()` nobody writes into leaves where the superclass would have been.
    @Test
    func namesThePathOfEachContainer() throws {
        struct Probe: Encodable {
            enum CodingKeys: String, CodingKey {
                case list, dict, base
            }

            enum InnerKeys: String, CodingKey {
                case x
            }

            func encode(to encoder: any Encoder) throws {
                #expect(encoder.codingPath.isEmpty)

                var container = encoder.container(keyedBy: CodingKeys.self)
                #expect(container.codingPath.isEmpty)

                var list = container.nestedUnkeyedContainer(forKey: .list)
                #expect(list.codingPath.map(\.stringValue) == ["list"])

                let first = list.nestedContainer(keyedBy: InnerKeys.self)
                #expect(first.codingPath.map(\.stringValue) == ["list", "Index 0"])

                let second = list.superEncoder()
                #expect(second.codingPath.map(\.stringValue) == ["list", "Index 1"])

                let dict = container.nestedContainer(keyedBy: InnerKeys.self, forKey: .dict)
                #expect(dict.codingPath.map(\.stringValue) == ["dict"])

                let base = container.superEncoder(forKey: .base)
                #expect(base.codingPath.map(\.stringValue) == ["base"])

                let absent = container.superEncoder()
                #expect(absent.codingPath.map(\.stringValue) == ["super"])
            }
        }

        #expect(
            try encoder.encode(Probe()) == [
                "list": [[:], [:]],
                "dict": [:],
                "base": [:],
                "super": [:],
            ]
        )
    }

    // MARK: - Null

    // A `nil` with nothing around it is the fragment `PropertyListEncoder` refuses most plainly,
    // and here it is the sentinel on its own — the same value it would be under a key or at an
    // index.
    @Test
    func writesATopLevelNilAsTheSentinel() throws {
        #expect(try encoder.encode(String?.none) == .null)
        #expect(try encoder.encode(String?.some("a")) == .string("a"))
    }

    // `encodeNil(forKey:)` is what the documentation on the keyed container calls a caller asking
    // for the sentinel on purpose, and this is the sentinel it gets.
    @Test
    func writesTheSentinelWhenAskedToUnderAKey() throws {
        struct Explicit: Encodable {
            enum CodingKeys: String, CodingKey {
                case nickname
            }

            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeNil(forKey: .nickname)
            }
        }

        #expect(try encoder.encode(Explicit()) == ["nickname": .null])
    }

    // Written as the real they are. The format spells all three in words, and handing them over
    // unchanged is what lets it.
    @Test
    func writesTheRealsThatAreNotNumbers() throws {
        #expect(try encoder.encode(Double.nan).real?.isNaN == true)
        #expect(try encoder.encode(Float.infinity) == .real(.infinity))
        #expect(try encoder.encode(-Double.infinity) == .real(-.infinity))
    }

    // MARK: - Writing a PropertyListValue

    // A value handed over as itself is written as it is rather than encoded again. Nothing here
    // would change if it were encoded again — every case writes back as that case — so what this
    // pins is the result, not the shortcut that reaches it.
    @Test(arguments: [
        PropertyListValue.integer(1),
        .real(2),
        .bool(true),
        .string("Jane Doe"),
        .data(Data([0x00, 0xFF])),
        .date(Date(timeIntervalSinceReferenceDate: 0)),
        .unsignedInteger(UInt64(Int64.max) + 1),
        .array([.integer(1), .real(2)]),
        .dictionary(["flag": .integer(1), "score": .real(2)]),
    ])
    func writesAPropertyListValueAsItIs(_ value: PropertyListValue) throws {
        #expect(try encoder.encode(value) == value)
        #expect(try encoder.encode(["value": value]) == .dictionary(["value": value]))
        #expect(try encoder.encode([value]) == .array([value]))
    }

    // MARK: - Round trip

    @Test
    func survivesARoundTripThroughTheDecoder() throws {
        let profile = Profile(name: "Jane Doe", age: 30, tags: ["swift", "macOS"], nickname: "Janie")

        #expect(try decoder.decode(Profile.self, from: encoder.encode(profile)) == profile)
    }

    // Only where the bridge to the `Any` form is compiled in, which away from Apple platforms is
    // behind the `ValueFoundation` trait.
    #if ValueFoundation || !canImport(FoundationEssentials)
    @Test
    func survivesARoundTripThroughTheAnyForm() throws {
        let profile = Profile(name: "Jane Doe", age: 30, tags: ["swift"], nickname: nil)
        let stored = try encoder.encode(profile).propertyList
        let restored = try #require(PropertyListValue(propertyList: stored))

        #expect(try decoder.decode(Profile.self, from: restored) == profile)
    }
    #endif

    // What the sentinel is for, checked end to end rather than one side at a time.
    @Test
    func survivesARoundTripWithNilElements() throws {
        let names = ["a", nil, "b"] as [String?]

        #expect(try decoder.decode([String?].self, from: encoder.encode(names)) == names)
    }

    // MARK: - Interoperability

    // The other direction of the decoder's test of the same name: what this encoder builds,
    // serialized by Foundation and read back by Foundation's decoder into the type it came from.
    // The sentinel, the `super` key and the native `Date` and `Data` all have to be what
    // `PropertyListDecoder` expects to find, in both formats it reads.
    @Test(arguments: [PropertyListSerialization.PropertyListFormat.binary, .xml])
    func writesWhatFoundationReads(_ format: PropertyListSerialization.PropertyListFormat) throws {
        let foundation = PropertyListDecoder()

        let record = Record(
            profile: Profile(name: "Jane Doe", age: 30, tags: ["swift"], nickname: "Janie"),
            updatedAt: Date(timeIntervalSinceReferenceDate: 5),
            avatar: Data([0xDE, 0xAD])
        )
        let names = ["a", nil, "b"] as [String?]
        let car = Car(kind: "hatchback", doors: 5)

        #expect(
            try foundation.decode(Record.self, from: encoder.encode(record).serialized(as: format))
                == record
        )
        #expect(
            try foundation.decode(
                [String?].self,
                from: encoder.encode(names).serialized(as: format)
            ) == names
        )

        let restored = try foundation.decode(
            Car.self,
            from: encoder.encode(car).serialized(as: format)
        )

        #expect(restored.kind == "hatchback")
        #expect(restored.doors == 5)
    }

    // MARK: - Inheritance

    @Test
    func writesASuperclassThroughItsOwnEncoder() throws {
        class Base: Codable {
            var kind: String

            init(kind: String) {
                self.kind = kind
            }
        }

        final class Derived: Base {
            var extra: Int

            private enum CodingKeys: String, CodingKey {
                case extra
            }

            init(kind: String, extra: Int) {
                self.extra = extra

                super.init(kind: kind)
            }

            required init(from decoder: any Decoder) throws {
                fatalError("unused")
            }

            override func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(extra, forKey: .extra)
                try super.encode(to: container.superEncoder())
            }
        }

        let value = try encoder.encode(Derived(kind: "widget", extra: 9))

        #expect(
            value == .dictionary([
                "extra": .integer(9),
                "super": .dictionary(["kind": .string("widget")]),
            ])
        )
    }

    // MARK: - Container misuse

    // A key that already holds a value cannot also hold a container: honouring the second ask means
    // dropping what the first one wrote, and doing it silently. Refusing is a `preconditionFailure`,
    // which takes the process with it — so these run in a child one, which is the only way a trap is
    // testable at all. `precondition` survives `-O`, so the release rows in CI execute them rather
    // than compiling them away.
    //
    // Only where a child process can be spawned. The platforms left out are the ones the testing
    // library cannot do it on, not ones where the precondition does not hold.
    #if os(macOS) || os(Linux) || os(FreeBSD) || os(OpenBSD) || os(Windows)
    @Test
    func refusesAContainerForAKeyThatAlreadyHoldsAValue() async {
        await #expect(processExitsWith: .failure) {
            struct Clash: Encodable {
                enum CodingKeys: String, CodingKey {
                    case k
                }

                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(1, forKey: .k)

                    var nested = container.nestedUnkeyedContainer(forKey: .k)
                    try nested.encode(2)
                }
            }

            _ = try? PropertyListValueEncoder().encode(Clash())
        }
    }

    // And the other pairing the same storage has to refuse: a key holding one kind of container
    // cannot be asked for the other. Two cases, two messages, one rule — this is what says the two
    // agree.
    @Test
    func refusesAContainerOfTheOtherKindForTheSameKey() async {
        await #expect(processExitsWith: .failure) {
            struct Clash: Encodable {
                enum CodingKeys: String, CodingKey {
                    case k
                }

                enum Nested: String, CodingKey {
                    case x
                }

                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    var array = container.nestedUnkeyedContainer(forKey: .k)
                    try array.encode(1)

                    var dictionary = container.nestedContainer(keyedBy: Nested.self, forKey: .k)
                    try dictionary.encode(2, forKey: .x)
                }
            }

            _ = try? PropertyListValueEncoder().encode(Clash())
        }
    }

    // The single value container's half of the same rule: one node holds one value, and a second
    // write through the same container would otherwise drop the first one silently.
    @Test
    func refusesASecondValueThroughASingleValueContainer() async {
        await #expect(processExitsWith: .failure) {
            struct Twice: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.singleValueContainer()
                    try container.encode(1)
                    try container.encode(2)
                }
            }

            _ = try? PropertyListValueEncoder().encode(Twice())
        }
    }

    // And the pairing across kinds: a node that already holds a value cannot hand out a container,
    // which is the ask that would replace the value with an empty dictionary.
    @Test
    func refusesAContainerAfterAValueHasBeenEncoded() async {
        await #expect(processExitsWith: .failure) {
            struct Clash: Encodable {
                enum CodingKeys: String, CodingKey {
                    case k
                }

                func encode(to encoder: any Encoder) throws {
                    var single = encoder.singleValueContainer()
                    try single.encode(1)

                    _ = encoder.container(keyedBy: CodingKeys.self)
                }
            }

            _ = try? PropertyListValueEncoder().encode(Clash())
        }
    }
    #endif

    // MARK: - Errors

    @Test
    func refusesAValueThatEncodesNothingAtTheTop() {
        struct Silent: Encodable {
            func encode(to encoder: any Encoder) throws {}
        }

        #expect(throws: EncodingError.self) {
            try encoder.encode(Silent())
        }
    }

    // The widest number the value model carries is `UInt64`, and nothing narrows silently to reach
    // it: `SingleValueEncodingContainer` has no `Int128` method that this implements, so the
    // standard library's own default refuses with `Encoder has not implemented support for Int128`.
    // Pinned because the alternative — a value quietly losing its top half — is the failure that
    // would not announce itself.
    //
    // visionOS is spelled out even though it need not be: Swift derives a missing visionOS
    // availability from the iOS one, so `iOS 18.0` alone already satisfies `Int128`'s `visionOS 2.0`
    // — dropping the iOS entry is what makes a visionOS build fail, not dropping this. Saying it
    // anyway means a reader can check the line against the standard library without knowing that
    // rule.
    @Test
    @available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func refusesAnIntegerWiderThanThePropertyListFormatHas() {
        #expect(throws: EncodingError.self) {
            try encoder.encode(Int128.max)
        }
    }
}
