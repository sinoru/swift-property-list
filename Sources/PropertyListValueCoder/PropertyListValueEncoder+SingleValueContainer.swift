//
//  PropertyListValueEncoder+SingleValueContainer.swift
//  PropertyListValueCoder
//

import PropertyListValue

extension PropertyListValueEncoder._Encoder: SingleValueEncodingContainer {
    /// Fills the one slot this node has, and refuses to fill it twice.
    ///
    /// `Encoder` lets a value ask for exactly one container and write into it once. Silently
    /// dropping the first value would turn that mistake into a wrong property list rather than a
    /// stopped program.
    ///
    /// `consuming` for the reason given on ``PropertyListFuture``: the value is kept, not read.
    private func store(_ value: consuming PropertyListValue) {
        precondition(
            singleValue == nil && array == nil && dictionary == nil,
            "Attempt to encode a value through a single value container where one has already been encoded."
        )

        singleValue = value
    }

    /// Writes the null sentinel as this node's value.
    func encodeNil() throws {
        store(.null)
    }

    /// Writes a `Bool` as this node's value.
    func encode(_ value: Bool) throws {
        store(wrapBool(value))
    }

    /// Writes a `String` as this node's value.
    func encode(_ value: String) throws {
        store(wrapString(value))
    }

    /// Writes a `Double` as this node's value.
    func encode(_ value: Double) throws {
        store(wrapFloatingPoint(value))
    }

    /// Writes a `Float` as this node's value.
    func encode(_ value: Float) throws {
        store(wrapFloatingPoint(value))
    }

    /// Writes an `Int` as this node's value.
    func encode(_ value: Int) throws {
        try store(wrapInteger(value))
    }

    /// Writes an `Int8` as this node's value.
    func encode(_ value: Int8) throws {
        try store(wrapInteger(value))
    }

    /// Writes an `Int16` as this node's value.
    func encode(_ value: Int16) throws {
        try store(wrapInteger(value))
    }

    /// Writes an `Int32` as this node's value.
    func encode(_ value: Int32) throws {
        try store(wrapInteger(value))
    }

    /// Writes an `Int64` as this node's value.
    func encode(_ value: Int64) throws {
        try store(wrapInteger(value))
    }

    /// Writes a `UInt` as this node's value.
    func encode(_ value: UInt) throws {
        try store(wrapInteger(value))
    }

    /// Writes a `UInt8` as this node's value.
    func encode(_ value: UInt8) throws {
        try store(wrapInteger(value))
    }

    /// Writes a `UInt16` as this node's value.
    func encode(_ value: UInt16) throws {
        try store(wrapInteger(value))
    }

    /// Writes a `UInt32` as this node's value.
    func encode(_ value: UInt32) throws {
        try store(wrapInteger(value))
    }

    /// Writes a `UInt64` as this node's value.
    func encode(_ value: UInt64) throws {
        try store(wrapInteger(value))
    }

    /// Writes any other `Encodable` value as this node's value.
    func encode<T>(_ value: T) throws where T: Encodable {
        try store(wrap(value, forKey: nil))
    }
}
