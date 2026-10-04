//
//  PropertyListValueTests.swift
//  PropertyListTests
//

// Everything here reads through the bridge to Foundation's `Any`, which is gated the same way:
// where FoundationEssentials can be imported, it waits for the `ValueFoundation` trait.
#if ValueFoundation || !canImport(FoundationEssentials)
import Foundation
import Testing

import PropertyListValue

@Suite("PropertyListValue")
struct PropertyListValueTests {
    // MARK: - Round Trip

    // Asserts the value rather than the Swift type it lands on, because that type is not the same
    // everywhere: `Int` is 32 bits on arm64_32, so a value `Int` cannot hold there stays an `Int64`.
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
        .real(0),
        .real(-1.5),
        .real(.infinity),
        .array([]),
        .array([.integer(1), .string("two"), .bool(true), .real(3.5)]),
        .dictionary([:]),
        .dictionary(["name": .string("Jane Doe"), "age": .integer(30)]),
        .array([.dictionary(["tags": .array([.string("swift")])])]),
    ])
    func survivesARoundTripThroughItsPropertyListForm(_ value: PropertyListValue) throws {
        let restored = try #require(PropertyListValue(propertyList: value.propertyList))

        #expect(restored == value)
    }

    // MARK: - Bool

    // The distinction the whole type exists to keep. On Darwin every number arrives as one
    // `NSNumber` type and `NSNumber(value: 1) as? Bool` succeeds, so these two are exactly what a
    // ladder of Swift casts would collapse together.
    @Test
    func readsATrueBooleanRatherThanTheNumberOne() {
        #expect(PropertyListValue(propertyList: true) == .bool(true))
        #expect(PropertyListValue(propertyList: 1) == .integer(1))
    }

    @Test
    func readsAFalseBooleanRatherThanTheNumberZero() {
        #expect(PropertyListValue(propertyList: false) == .bool(false))
        #expect(PropertyListValue(propertyList: 0) == .integer(0))
    }

    // MARK: - Numbers

    // The other collapse a cast ladder would make: `NSNumber` bridging is exactness-checked, so a
    // stored `<real>2</real>` passes `as? Int64` and would arrive as an integer.
    @Test
    func readsAnIntegralRealAsAReal() {
        #expect(PropertyListValue(propertyList: 2.0) == .real(2))
    }

    @Test
    func widensAFloatIntoAReal() {
        #expect(PropertyListValue(propertyList: Float(0.5)) == .real(0.5))
    }

    // The spellings swift-corelibs-foundation reaches for at the ends of the signed range, which is
    // where a ladder written in terms of `Int` alone stops matching.
    @Test
    func readsTheSignedIntegerSpellingsAsOneCase() {
        #expect(PropertyListValue(propertyList: Int.max) == .integer(Int64(Int.max)))
        #expect(PropertyListValue(propertyList: Int64.max) == .integer(Int64.max))
        #expect(PropertyListValue(propertyList: Int64.min) == .integer(Int64.min))
        #expect(PropertyListValue(propertyList: Int8(-1)) == .integer(-1))
        #expect(PropertyListValue(propertyList: UInt32(7)) == .integer(7))
    }

    // `unsignedInteger` carries only what `integer` cannot, so that one number has one spelling.
    @Test
    func readsAnUnsignedValueAsAnIntegerWhileItFits() {
        #expect(PropertyListValue(propertyList: UInt64(7)) == .integer(7))
        #expect(PropertyListValue(propertyList: UInt64(Int64.max)) == .integer(Int64.max))
        #expect(
            PropertyListValue(propertyList: UInt64(Int64.max) + 1)
                == .unsignedInteger(UInt64(Int64.max) + 1)
        )
    }

    // MARK: - Foundation Objects

    // What Darwin's `UserDefaults` and `PropertyListSerialization` actually hand back, rather than
    // the Swift values the round trip above starts from. The two small `NSNumber`s are the pair the
    // branch away from Darwin has to work hardest on: swift-corelibs-foundation gives a boolean and
    // an `Int8` the same `objCType` of `c`, and only identity against the boolean singletons tells
    // them apart. `100` sits outside the small-integer cache that would otherwise retype `1` as an
    // `Int32` and so never reach that comparison.
    @Test
    func readsTheFoundationObjectsThePlatformHandsBack() {
        #expect(PropertyListValue(propertyList: NSNumber(value: true)) == .bool(true))
        #expect(PropertyListValue(propertyList: NSNumber(value: false)) == .bool(false))
        #expect(PropertyListValue(propertyList: NSNumber(value: Int8(1))) == .integer(1))
        #expect(PropertyListValue(propertyList: NSNumber(value: Int8(100))) == .integer(100))
        #expect(PropertyListValue(propertyList: NSNumber(value: Float(0.5))) == .real(0.5))
        #expect(PropertyListValue(propertyList: NSNumber(value: 2.0)) == .real(2))
        #expect(
            PropertyListValue(propertyList: NSNumber(value: UInt64.max)) == .unsignedInteger(.max)
        )
        #expect(
            PropertyListValue(propertyList: NSString(string: "Jane Doe")) == .string("Jane Doe")
        )
        #expect(
            PropertyListValue(propertyList: NSDate(timeIntervalSinceReferenceDate: 0))
                == .date(Date(timeIntervalSinceReferenceDate: 0))
        )
        #expect(PropertyListValue(propertyList: NSData(data: Data([0xFF]))) == .data(Data([0xFF])))
        #expect(
            PropertyListValue(
                propertyList: NSArray(array: [NSNumber(value: 1), NSString(string: "two")])
            ) == [1, "two"]
        )
        #expect(
            PropertyListValue(propertyList: NSDictionary(dictionary: ["age": NSNumber(value: 30)]))
                == ["age": 30]
        )
    }

    // MARK: - Rejection

    private struct NotAPropertyListValue: Sendable {}

    @Test
    func rejectsAValueThePropertyListFormatCannotHold() {
        #expect(PropertyListValue(propertyList: NotAPropertyListValue()) == nil)
    }

    @Test
    func rejectsACollectionHoldingOneAnywhereInside() {
        #expect(PropertyListValue(propertyList: [NotAPropertyListValue()] as [Any]) == nil)
        #expect(
            PropertyListValue(propertyList: ["key": NotAPropertyListValue()] as [String: Any]) == nil
        )
        #expect(
            PropertyListValue(
                propertyList: [["deep": [NotAPropertyListValue()]]] as [Any]
            ) == nil
        )
    }

    // A property list keys its dictionaries by string and nothing else.
    @Test
    func rejectsADictionaryKeyedBySomethingOtherThanAString() {
        #expect(PropertyListValue(propertyList: [1: "one"] as [AnyHashable: Any]) == nil)
    }

    // Two objects the binary format has a marker for, and so can produce, that
    // `CFPropertyListIsValid` nonetheless refuses. Neither is a property list value, so nothing
    // here answers for them — at the top or inside a collection.
    @Test
    func rejectsANullAndASet() {
        #expect(PropertyListValue(propertyList: NSNull()) == nil)
        #expect(PropertyListValue(propertyList: NSSet(array: [1])) == nil)
        #expect(PropertyListValue(propertyList: [NSNull()] as [Any]) == nil)
    }

    private final class NotAnNSObject {}

    // An object of a class Swift roots itself, rather than `NSObject`, is still an object on Darwin
    // and is read as one. It is nothing a property list holds.
    @Test
    func rejectsAnObjectThatIsNotAnNSObject() {
        #expect(PropertyListValue(propertyList: NotAnNSObject()) == nil)
        #expect(PropertyListValue(propertyList: [NotAnNSObject()] as [Any]) == nil)
    }

#if os(macOS)
    // A proxy answers what it is asked by forwarding it, and one that will not forward a message
    // raises instead. Darwin tells its objects apart by asking CoreFoundation for a type ID, which
    // asks an object that is not CoreFoundation's own — so a proxy handed over as a value, or found
    // inside a collection, has to be turned away before that question rather than by it. Anything
    // short of that does not fail this test; it ends the process.
    //
    // macOS alone, because `NSProtocolChecker` is: no other platform's Foundation has it, and
    // `NSProxy` cannot be subclassed from Swift to stand in for it, having no initializer to call.
    // What is tested is one line the other Apple platforms compile unchanged.
    @Test
    func rejectsAProxyWithoutSendingItAMessage() {
        let proxy = NSProtocolChecker(target: NSObject(), protocol: (any NSObjectProtocol).self)

        #expect(PropertyListValue(propertyList: proxy) == nil)
        #expect(PropertyListValue(propertyList: NSArray(array: [proxy])) == nil)
        #expect(PropertyListValue(propertyList: NSDictionary(dictionary: ["key": proxy])) == nil)
    }
#endif

    // A string Swift built at run time is its own storage class when it crosses into an object,
    // not one of Foundation's. It is turned away by nothing that turns the objects above away.
    @Test
    func readsAStringBuiltAtRunTime() {
        let string = String(repeating: "property list ", count: 8)

        #expect(PropertyListValue(propertyList: string) == .string(string))
        #expect(PropertyListValue(propertyList: [string] as [Any]) == [.string(string)])
        #expect(
            PropertyListValue(propertyList: [string: string] as [String: Any])
                == [string: .string(string)]
        )
    }
}
#endif
