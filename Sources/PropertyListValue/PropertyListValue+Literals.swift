//
//  PropertyListValue+Literals.swift
//  PropertyList
//

// No `ExpressibleByNilLiteral`: a property list has no null, so there is no value for `nil` to
// mean here. What an encoder writes for a `nil` is a sentinel it agrees on with a decoder, which
// is `PropertyListValue.null` and deliberately not spelled as a literal.

extension PropertyListValue: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension PropertyListValue: ExpressibleByIntegerLiteral {
    /// An integer literal is `Int64` rather than `Int` so that the widest one a property list can
    /// carry is still a literal on a 32-bit platform, and ``unsignedInteger`` stays reachable only
    /// through what `Int64` cannot hold.
    ///
    /// That leaves the top of the format's range with no literal spelling: every value above
    /// `Int64.max`, up to the `UInt64.max` where both parsers stop, is written
    /// ``unsignedInteger(_:)`` instead. The type that would cover it is `StaticBigInt`, and it
    /// cannot be used here — it begins at macOS 13.3, iOS 16.4, watchOS 9.4 and tvOS 16.4, further
    /// forward than this package deploys on any of them, and `ExpressibleByIntegerLiteral` wants
    /// its literal type across the whole deployment range rather than somewhere an `@available`
    /// could fence it off.
    ///
    /// Little is given up for that. A number that large is something data carries rather than
    /// something source states, and every way one arrives — ``init(data:)``,
    /// ``init(propertyList:)``, a decoder — already reads it into ``unsignedInteger``. A literal out
    /// of range is refused by the compiler, which is the diagnosis `StaticBigInt` could not have
    /// given: `init(integerLiteral:)` cannot throw, so checking the width inside it would trap at
    /// run time instead.
    @inlinable
    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }
}

extension PropertyListValue: ExpressibleByFloatLiteral {
    @inlinable
    public init(floatLiteral value: Double) {
        self = .real(value)
    }
}

extension PropertyListValue: ExpressibleByBooleanLiteral {
    @inlinable
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}

extension PropertyListValue: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: PropertyListValue...) {
        self = .array(elements)
    }
}

extension PropertyListValue: ExpressibleByDictionaryLiteral {
    /// Traps on a duplicate key, which is what a dictionary literal does everywhere else in Swift.
    @inlinable
    public init(dictionaryLiteral elements: (String, PropertyListValue)...) {
        self = .dictionary(Dictionary(uniqueKeysWithValues: elements))
    }
}
