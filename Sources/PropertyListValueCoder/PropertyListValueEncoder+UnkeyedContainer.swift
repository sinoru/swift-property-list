//
//  PropertyListValueEncoder+UnkeyedContainer.swift
//  PropertyListValueCoder
//

import PropertyListValue

extension PropertyListValueEncoder {
    /// The unkeyed container over an array under construction: what a type writing its elements in
    /// order is handed.
    struct UnkeyedContainer: UnkeyedEncodingContainer {
        /// The encoder whose node the array is, which errors and nested encoders hang off.
        let encoder: _Encoder
        /// The array being written into.
        let array: PropertyListFuture.RefArray

        /// The keys leading to the array, which are its encoder's.
        var codingPath: [any CodingKey] {
            encoder.codingPath
        }

        /// The number of elements written so far.
        var count: Int {
            array.count
        }

        /// The key naming where the next element will go, for an error that has to say.
        private var nextKey: PropertyListCodingKey {
            .index(array.count)
        }

        /// Writes the null sentinel as the next element.
        ///
        /// The one place a `nil` inside a property list has nowhere else to go. A keyed container
        /// omits the key; an array cannot omit an element without moving every one after it, so the
        /// position has to be held by something — and ``PropertyListValue/null`` is what Foundation
        /// holds it with.
        mutating func encodeNil() throws {
            array.append(.null)
        }

        /// Writes a `Bool` as the next element.
        mutating func encode(_ value: Bool) throws {
            array.append(encoder.wrapBool(value))
        }

        /// Writes a `String` as the next element.
        mutating func encode(_ value: String) throws {
            array.append(encoder.wrapString(value))
        }

        /// Writes a `Double` as the next element.
        mutating func encode(_ value: Double) throws {
            array.append(encoder.wrapFloatingPoint(value))
        }

        /// Writes a `Float` as the next element.
        mutating func encode(_ value: Float) throws {
            array.append(encoder.wrapFloatingPoint(value))
        }

        /// Writes an `Int` as the next element.
        mutating func encode(_ value: Int) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes an `Int8` as the next element.
        mutating func encode(_ value: Int8) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes an `Int16` as the next element.
        mutating func encode(_ value: Int16) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes an `Int32` as the next element.
        mutating func encode(_ value: Int32) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes an `Int64` as the next element.
        mutating func encode(_ value: Int64) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes a `UInt` as the next element.
        mutating func encode(_ value: UInt) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes a `UInt8` as the next element.
        mutating func encode(_ value: UInt8) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes a `UInt16` as the next element.
        mutating func encode(_ value: UInt16) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes a `UInt32` as the next element.
        mutating func encode(_ value: UInt32) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes a `UInt64` as the next element.
        mutating func encode(_ value: UInt64) throws {
            try array.append(encoder.wrapInteger(value, forKey: nextKey))
        }

        /// Writes any other `Encodable` value as the next element, encoded into a node of its own.
        mutating func encode<T>(_ value: T) throws where T: Encodable {
            try array.append(encoder.wrap(value, forKey: nextKey))
        }

        /// A keyed container writing into a new dictionary that is the next element.
        mutating func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            let key = nextKey

            return KeyedEncodingContainer(
                KeyedContainer<NestedKey>(
                    encoder: encoder.encoder(forKey: key),
                    dictionary: array.appendDictionary()
                )
            )
        }

        /// An unkeyed container writing into a new array that is the next element.
        mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
            let key = nextKey

            return UnkeyedContainer(
                encoder: encoder.encoder(forKey: key),
                array: array.appendArray()
            )
        }

        /// An encoder for a superclass, whose value lands at the next position when the encoder is
        /// released.
        mutating func superEncoder() -> any Encoder {
            _ReferencingEncoder(owner: encoder, at: array.reserve(), wrapping: array)
        }
    }
}
