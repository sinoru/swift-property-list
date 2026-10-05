//
//  PropertyListValueDecoder+KeyedContainer.swift
//  PropertyListValueCoder
//

import PropertyListValue

extension PropertyListValueDecoder {
    /// The keyed container over a dictionary: what a type reading its properties by key is handed.
    struct KeyedContainer<Key>: KeyedDecodingContainerProtocol where Key: CodingKey {
        /// The decoder whose value the dictionary is, which errors and nested decoders hang off.
        let decoder: _Decoder
        /// The dictionary being read.
        let dictionary: [String: PropertyListValue]

        /// The keys leading to the dictionary, which are its decoder's.
        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        /// Every key in the dictionary that `Key` can be made from.
        var allKeys: [Key] {
            dictionary.keys.compactMap(Key.init(stringValue:))
        }

        /// Whether the dictionary holds a value under a key, the null sentinel included.
        func contains(_ key: Key) -> Bool {
            dictionary[key.stringValue] != nil
        }

        /// The value under a key, or the error that says there is none.
        ///
        /// A missing key and a key holding ``PropertyListValue/null`` are different things, and only
        /// the first is reported here — a synthesized `Decodable` reaches `decodeNil(forKey:)` for
        /// the second.
        private func value(forKey key: Key) throws -> PropertyListValue {
            guard let value = dictionary[key.stringValue] else {
                throw DecodingError.keyNotFound(
                    key,
                    DecodingError.Context(
                        codingPath: codingPath,
                        debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")."
                    )
                )
            }

            return value
        }

        /// Whether the value under a key is the null sentinel.
        ///
        /// - Throws: `DecodingError.keyNotFound` when there is no such key.
        func decodeNil(forKey key: Key) throws -> Bool {
            try value(forKey: key).isNull
        }

        /// Reads the value under a key as a `Bool`.
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            try unwrapBool(value(forKey: key), in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `String`.
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            try unwrapString(value(forKey: key), in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `Double`.
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try unwrapFloatingPoint(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `Float`.
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            try unwrapFloatingPoint(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int`.
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int8`.
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int16`.
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int32`.
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int64`.
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt`.
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt8`.
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt16`.
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt32`.
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt64`.
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            try unwrapInteger(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as any other `Decodable` type, making a decoder for it only
        /// if the type has to decode itself.
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
            try unwrap(value(forKey: key), as: type, in: decoder, forKey: key)
        }

        /// The value under a key, or `nil` where there is nothing to read: no such key, or one
        /// holding ``PropertyListValue/null``.
        ///
        /// What every `decodeIfPresent` below starts from, and the reason they are written out.
        /// The ones the standard library supplies ask `contains(_:)`, then `decodeNil(forKey:)`,
        /// then `decode(_:forKey:)`, and each of those looks the key up again — three hashes of
        /// the same string for every optional property a synthesized `Decodable` reads. Here it is
        /// looked up once.
        private func valueIfPresent(forKey key: Key) -> PropertyListValue? {
            guard let value = dictionary[key.stringValue], !value.isNull else { return nil }

            return value
        }

        /// Reads the value under a key as a `Bool`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapBool(value, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `String`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapString(value, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `Double`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapFloatingPoint(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `Float`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapFloatingPoint(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int8`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int16`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int32`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as an `Int64`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt8`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt16`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt32`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as a `UInt64`, or `nil` where the key is absent or holds the
        /// null sentinel.
        func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrapInteger(value, as: type, in: decoder, forKey: key)
        }

        /// Reads the value under a key as any other `Decodable` type, or `nil` where the key is
        /// absent or holds the null sentinel.
        func decodeIfPresent<T>(_ type: T.Type, forKey key: Key) throws -> T? where T: Decodable {
            guard let value = valueIfPresent(forKey: key) else { return nil }

            return try unwrap(value, as: type, in: decoder, forKey: key)
        }

        /// A keyed container over the dictionary under a key.
        func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type,
            forKey key: Key
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            try decoder.decoder(for: value(forKey: key), forKey: key).container(keyedBy: type)
        }

        /// An unkeyed container over the array under a key.
        func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
            try decoder.decoder(for: value(forKey: key), forKey: key).unkeyedContainer()
        }

        /// The decoder a subclass reads itself from.
        ///
        /// A class that inherits `Decodable` encodes its superclass's half under `super` unless it
        /// says otherwise. An absent key stands in as ``PropertyListValue/null`` rather than as an
        /// empty dictionary: a superclass that stores nothing asks for no container and so never
        /// looks at it, while one that does ask gets the same `valueNotFound` Foundation gives it.
        /// Standing in with an empty dictionary instead would answer that ask by inventing a
        /// superclass with every property missing, which is a decode that should have failed.
        func superDecoder() throws -> any Decoder {
            try superDecoder(forKey: PropertyListCodingKey.super)
        }

        /// The decoder for a superclass stored under a key of the caller's choosing.
        func superDecoder(forKey key: Key) throws -> any Decoder {
            try superDecoder(forKey: key as any CodingKey)
        }

        /// The decoder for whatever is under a key, with the null sentinel standing in where
        /// nothing is.
        private func superDecoder(forKey key: any CodingKey) throws -> any Decoder {
            decoder.decoder(for: dictionary[key.stringValue] ?? .null, forKey: key)
        }
    }
}
