//
//  PropertyListValue+Values.swift
//  PropertyList
//

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

// Read-only, and that is the format talking rather than a smaller API for its own sake. A setter
// here would need an answer for what assigning `nil` means, and the two a null-carrying format can
// give — write a null, or drop the value — are both unavailable: a property list has no null, and a
// value on its own has nowhere to be dropped from. Assigning a case says the same thing without the
// question: `value = .string("x")`.
//
// Absence does have a form once there is a container to be absent from, which is why the
// subscripts in `PropertyListValue+Subscripts.swift` do take a `nil`.
//
// Each of these answers for one case and no other. A `<real>2</real>` read through ``integer`` is
// `nil` rather than `2`, because the question was which case this is; anything wanting a number
// whichever way it was written asks both and converts.
extension PropertyListValue {
    /// The dictionary this holds, or `nil` if it holds something else.
    @inlinable
    public var dictionary: [String: PropertyListValue]? {
        guard case let .dictionary(dictionary) = self else { return nil }
        return dictionary
    }

    /// The array this holds, or `nil` if it holds something else.
    @inlinable
    public var array: [PropertyListValue]? {
        guard case let .array(array) = self else { return nil }
        return array
    }

    /// The string this holds, or `nil` if it holds something else.
    @inlinable
    public var string: String? {
        guard case let .string(string) = self else { return nil }
        return string
    }

    /// The data this holds, or `nil` if it holds something else.
    @inlinable
    public var data: Data? {
        guard case let .data(data) = self else { return nil }
        return data
    }

    /// The date this holds, or `nil` if it holds something else.
    @inlinable
    public var date: Date? {
        guard case let .date(date) = self else { return nil }
        return date
    }

    /// The boolean this holds, or `nil` if it holds something else.
    ///
    /// `nil` for `<integer>1</integer>`, which is a different value from `<true/>` in the format
    /// and is kept as one here.
    @inlinable
    public var bool: Bool? {
        guard case let .bool(bool) = self else { return nil }
        return bool
    }

    /// The signed integer this holds, or `nil` if it holds something else.
    ///
    /// `nil` for a number above `Int64.max`, which is carried by ``unsignedInteger`` instead.
    @inlinable
    public var integer: Int64? {
        guard case let .integer(integer) = self else { return nil }
        return integer
    }

    /// The unsigned integer this holds, or `nil` if it holds something else.
    ///
    /// Only a number above `Int64.max` is stored this way, so this is `nil` for every number
    /// ``integer`` can answer for.
    @inlinable
    public var unsignedInteger: UInt64? {
        guard case let .unsignedInteger(unsignedInteger) = self else { return nil }
        return unsignedInteger
    }

    /// The floating-point number this holds, or `nil` if it holds something else.
    @inlinable
    public var real: Double? {
        guard case let .real(real) = self else { return nil }
        return real
    }
}
