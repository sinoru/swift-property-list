//
//  PropertyListValueEncoder+KeyedContainer.swift
//  PropertyListValueCoder
//

import PropertyListValue

extension PropertyListValueEncoder {
    /// The keyed container over a dictionary under construction: what a type writing its properties
    /// by key is handed.
    struct KeyedContainer<Key>: KeyedEncodingContainerProtocol where Key: CodingKey {
        /// The encoder whose node the dictionary is, which errors and nested encoders hang off.
        let encoder: _Encoder
        /// The dictionary being written into.
        let dictionary: PropertyListFuture.RefDictionary

        /// The keys leading to the dictionary, which are its encoder's.
        var codingPath: [any CodingKey] {
            encoder.codingPath
        }

        /// Writes the null sentinel under a key.
        ///
        /// A synthesized `Encodable` reaches this only for a property it was told to write even
        /// when nil — `encodeIfPresent` omits the key instead, which is what a property list would
        /// rather have. What lands here is a caller who asked for the sentinel on purpose.
        mutating func encodeNil(forKey key: Key) throws {
            dictionary.set(.null, for: key.stringValue)
        }

        /// Writes a `Bool` under a key.
        mutating func encode(_ value: Bool, forKey key: Key) throws {
            dictionary.set(encoder.wrapBool(value), for: key.stringValue)
        }

        /// Writes a `String` under a key.
        mutating func encode(_ value: String, forKey key: Key) throws {
            dictionary.set(encoder.wrapString(value), for: key.stringValue)
        }

        /// Writes a `Double` under a key.
        mutating func encode(_ value: Double, forKey key: Key) throws {
            dictionary.set(encoder.wrapFloatingPoint(value), for: key.stringValue)
        }

        /// Writes a `Float` under a key.
        mutating func encode(_ value: Float, forKey key: Key) throws {
            dictionary.set(encoder.wrapFloatingPoint(value), for: key.stringValue)
        }

        /// Writes an `Int` under a key.
        mutating func encode(_ value: Int, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes an `Int8` under a key.
        mutating func encode(_ value: Int8, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes an `Int16` under a key.
        mutating func encode(_ value: Int16, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes an `Int32` under a key.
        mutating func encode(_ value: Int32, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes an `Int64` under a key.
        mutating func encode(_ value: Int64, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes a `UInt` under a key.
        mutating func encode(_ value: UInt, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes a `UInt8` under a key.
        mutating func encode(_ value: UInt8, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes a `UInt16` under a key.
        mutating func encode(_ value: UInt16, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes a `UInt32` under a key.
        mutating func encode(_ value: UInt32, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes a `UInt64` under a key.
        mutating func encode(_ value: UInt64, forKey key: Key) throws {
            try dictionary.set(encoder.wrapInteger(value, forKey: key), for: key.stringValue)
        }

        /// Writes any other `Encodable` value under a key, encoded into a node of its own.
        mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
            try dictionary.set(encoder.wrap(value, forKey: key), for: key.stringValue)
        }

        /// A keyed container writing into the dictionary under a key, which is made if it is not
        /// there yet.
        mutating func nestedContainer<NestedKey>(
            keyedBy keyType: NestedKey.Type,
            forKey key: Key
        ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
            KeyedEncodingContainer(
                KeyedContainer<NestedKey>(
                    encoder: encoder.encoder(forKey: key),
                    dictionary: dictionary.setDictionary(for: key.stringValue)
                )
            )
        }

        /// An unkeyed container writing into the array under a key, which is made if it is not
        /// there yet.
        mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
            UnkeyedContainer(
                encoder: encoder.encoder(forKey: key),
                array: dictionary.setArray(for: key.stringValue)
            )
        }

        /// An encoder for a superclass, whose value lands under `super` when the encoder is
        /// released.
        mutating func superEncoder() -> any Encoder {
            _ReferencingEncoder(
                owner: encoder,
                key: PropertyListCodingKey.super,
                wrapping: dictionary
            )
        }

        /// An encoder for a superclass, whose value lands under the given key when the encoder is
        /// released.
        mutating func superEncoder(forKey key: Key) -> any Encoder {
            _ReferencingEncoder(owner: encoder, key: key, wrapping: dictionary)
        }
    }
}
