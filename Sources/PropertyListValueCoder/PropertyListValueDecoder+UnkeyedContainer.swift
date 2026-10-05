//
//  PropertyListValueDecoder+UnkeyedContainer.swift
//  PropertyListValueCoder
//

import PropertyListValue

extension PropertyListValueDecoder {
    /// The unkeyed container over an array: what a type reading its elements in order is handed.
    struct UnkeyedContainer: UnkeyedDecodingContainer {
        /// The decoder whose value the array is, which errors and nested decoders hang off.
        let decoder: _Decoder
        /// The array being read.
        let array: [PropertyListValue]

        /// The position of the element the next read returns.
        var currentIndex = 0

        /// The keys leading to the array, which are its decoder's.
        var codingPath: [any CodingKey] {
            decoder.codingPath
        }

        /// The number of elements in the array, which is always known.
        var count: Int? {
            array.count
        }

        /// Whether every element has been read.
        var isAtEnd: Bool {
            currentIndex >= array.count
        }

        /// The element at the current position, and the key that names where it is.
        ///
        /// Deliberately does not consume it. Advancing is the caller's last step, taken only once
        /// the value has been read successfully, because a `Decodable` is allowed to catch a
        /// mismatch and try the same element as another type — and a read that consumed on failure
        /// would hand the retry the element after it, or the end. Foundation's own containers
        /// advance in the same place for the same reason.
        private func current<T>(as type: T.Type) throws -> (value: PropertyListValue, key: any CodingKey) {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(
                    type,
                    DecodingError.Context(
                        codingPath: codingPath + [PropertyListCodingKey.index(currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            return (array[currentIndex], PropertyListCodingKey.index(currentIndex))
        }

        /// Whether the next element stands for `nil`, consuming it only when it does.
        ///
        /// Leaving the index alone otherwise is what `UnkeyedDecodingContainer` asks for: a caller
        /// that gets `false` back goes on to read the same element as a value.
        mutating func decodeNil() throws -> Bool {
            guard !isAtEnd else {
                throw DecodingError.valueNotFound(
                    Any?.self,
                    DecodingError.Context(
                        codingPath: codingPath + [PropertyListCodingKey.index(currentIndex)],
                        debugDescription: "Unkeyed container is at end."
                    )
                )
            }

            guard array[currentIndex].isNull else { return false }

            currentIndex += 1

            return true
        }

        /// Reads the next element as a `Bool`, and moves past it.
        mutating func decode(_ type: Bool.Type) throws -> Bool {
            let (value, key) = try current(as: type)
            let decoded = try unwrapBool(value, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `String`, and moves past it.
        mutating func decode(_ type: String.Type) throws -> String {
            let (value, key) = try current(as: type)
            let decoded = try unwrapString(value, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `Double`, and moves past it.
        mutating func decode(_ type: Double.Type) throws -> Double {
            let (value, key) = try current(as: type)
            let decoded = try unwrapFloatingPoint(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `Float`, and moves past it.
        mutating func decode(_ type: Float.Type) throws -> Float {
            let (value, key) = try current(as: type)
            let decoded = try unwrapFloatingPoint(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as an `Int`, and moves past it.
        mutating func decode(_ type: Int.Type) throws -> Int {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as an `Int8`, and moves past it.
        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as an `Int16`, and moves past it.
        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as an `Int32`, and moves past it.
        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as an `Int64`, and moves past it.
        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `UInt`, and moves past it.
        mutating func decode(_ type: UInt.Type) throws -> UInt {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `UInt8`, and moves past it.
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `UInt16`, and moves past it.
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `UInt32`, and moves past it.
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as a `UInt64`, and moves past it.
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            let (value, key) = try current(as: type)
            let decoded = try unwrapInteger(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// Reads the next element as any other `Decodable` type, and moves past it.
        mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
            let (value, key) = try current(as: type)
            let decoded = try unwrap(value, as: type, in: decoder, forKey: key)
            currentIndex += 1

            return decoded
        }

        /// A keyed container over the dictionary that is the next element, moving past it.
        mutating func nestedContainer<NestedKey>(
            keyedBy type: NestedKey.Type
        ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
            let (value, key) = try current(as: KeyedDecodingContainer<NestedKey>.self)
            let container = try decoder.decoder(for: value, forKey: key).container(keyedBy: type)
            currentIndex += 1

            return container
        }

        /// An unkeyed container over the array that is the next element, moving past it.
        mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
            let (value, key) = try current(as: (any UnkeyedDecodingContainer).self)
            let container = try decoder.decoder(for: value, forKey: key).unkeyedContainer()
            currentIndex += 1

            return container
        }

        /// A decoder for the next element, moving past it.
        mutating func superDecoder() throws -> any Decoder {
            let (value, key) = try current(as: (any Decoder).self)
            currentIndex += 1

            return decoder.decoder(for: value, forKey: key)
        }
    }
}
