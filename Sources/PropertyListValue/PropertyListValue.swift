//
//  PropertyListValue.swift
//  PropertyList
//

#if canImport(FoundationEssentials)
public import FoundationEssentials
#else
public import Foundation
#endif

/// A value in one of the shapes a property list can hold.
///
/// This is the model a property list actually has, not the one Swift would pick for it. It exists so
/// that encoding and decoding can happen against a typed tree instead of against `Any`, which is
/// what `UserDefaults` and `PropertyListSerialization` deal in — see ``init(propertyList:)`` and
/// ``propertyList``.
///
/// Three of the choices are worth spelling out, because each of them is a place where the format and
/// Swift disagree:
///
/// - There is no null. A property list has no such value, so a `nil` inside one is a convention
///   between an encoder and a decoder rather than something the format can carry. That convention
///   belongs to whoever writes those, not here.
/// - ``bool(_:)`` is separate from ``integer(_:)``. `<true/>` and `<integer>1</integer>` are
///   different values in the format, `defaults(1)` prints them differently, and a reader asking for
///   one when the other is stored is asking about the writer's intent — which is only answerable
///   while the two are still distinguishable.
/// - ``unsignedInteger(_:)`` exists only for what ``integer(_:)`` cannot hold, which is every value
///   above `Int64.max`. Keeping it to that leaves one spelling per number, so two values that are
///   the same number are also `==`. Anything building a `PropertyListValue` is expected to try
///   `Int64` first.
///
/// A `Float` widens into ``real(_:)`` rather than getting a case of its own. Nothing is lost by it:
/// every `Float` converts to `Double` exactly and converts back exactly, so the only difference is
/// four bytes in a binary property list.
public enum PropertyListValue: Hashable, Sendable {
    /// A dictionary, keyed by strings as the format requires.
    case dictionary([String: PropertyListValue])
    /// An array, whose elements need not share a case.
    case array([PropertyListValue])
    /// A string.
    case string(String)
    /// Bytes, stored as they are rather than as text.
    case data(Data)
    /// A point in time.
    case date(Date)
    /// A Boolean, which the format keeps apart from the numbers.
    case bool(Bool)
    /// An integer that `Int64` can hold.
    case integer(Int64)
    /// An integer above `Int64.max`, which is the only kind stored this way.
    case unsignedInteger(UInt64)
    /// A floating-point number.
    case real(Double)
}
