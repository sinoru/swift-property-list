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
