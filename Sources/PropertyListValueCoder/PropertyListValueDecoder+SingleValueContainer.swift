//
//  PropertyListValueDecoder+SingleValueContainer.swift
//  PropertyListValueCoder
//

import PropertyListValue

extension PropertyListValueDecoder._Decoder: SingleValueDecodingContainer {
    /// Whether the decoder's value is the null sentinel.
    func decodeNil() -> Bool {
        value.isNull
    }

    /// Reads the decoder's value as a `Bool`.
    func decode(_ type: Bool.Type) throws -> Bool {
        try PropertyListValueDecoder.unwrapBool(value, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `String`.
    func decode(_ type: String.Type) throws -> String {
        try PropertyListValueDecoder.unwrapString(value, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `Double`.
    func decode(_ type: Double.Type) throws -> Double {
        try PropertyListValueDecoder.unwrapFloatingPoint(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `Float`.
    func decode(_ type: Float.Type) throws -> Float {
        try PropertyListValueDecoder.unwrapFloatingPoint(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as an `Int`.
    func decode(_ type: Int.Type) throws -> Int {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as an `Int8`.
    func decode(_ type: Int8.Type) throws -> Int8 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as an `Int16`.
    func decode(_ type: Int16.Type) throws -> Int16 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as an `Int32`.
    func decode(_ type: Int32.Type) throws -> Int32 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as an `Int64`.
    func decode(_ type: Int64.Type) throws -> Int64 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `UInt`.
    func decode(_ type: UInt.Type) throws -> UInt {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `UInt8`.
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `UInt16`.
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `UInt32`.
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as a `UInt64`.
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        try PropertyListValueDecoder.unwrapInteger(value, as: type, in: self, forKey: nil)
    }

    /// Reads the decoder's value as any other `Decodable` type.
    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        try PropertyListValueDecoder.unwrap(value, as: type, in: self, forKey: nil)
    }
}
