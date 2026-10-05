//
//  PropertyListCodingKey.swift
//  PropertyListValueCoder
//

import PropertyListValue

/// The keys a container has to invent, for the two places `Codable` has no key of its own to give.
///
/// An unkeyed container names its elements by position, and `superDecoder()`/`superEncoder()` name
/// a slot that no `CodingKey` the caller wrote ever points at. Both only ever reach a caller inside
/// the `codingPath` of an error.
enum PropertyListCodingKey: CodingKey {
    /// The position of an element in an unkeyed container.
    case index(Int)
    /// The slot a superclass is written to when no key is given for it.
    case `super`

    /// The key as a coding path spells it: `Index 3`, or `super`.
    var stringValue: String {
        switch self {
        case .index(let index):
            "Index \(index)"
        case .super:
            "super"
        }
    }

    /// The position, for a key that names one.
    var intValue: Int? {
        switch self {
        case .index(let index):
            index
        case .super:
            nil
        }
    }

    /// Creates ``super`` from its spelling, and nothing from any other string.
    init?(stringValue: String) {
        guard stringValue == "super" else { return nil }

        self = .super
    }

    /// Creates the key for the element at a position.
    init?(intValue: Int) {
        self = .index(intValue)
    }
}
