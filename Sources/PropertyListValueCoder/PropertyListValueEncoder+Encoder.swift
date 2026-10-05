//
//  PropertyListValueEncoder+Encoder.swift
//  PropertyListValueCoder
//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import PropertyListValue

extension PropertyListValueEncoder {
    /// One node of the tree, being written.
    ///
    /// The three slots are mutually exclusive: whichever one is filled is what this node encoded to,
    /// and having all three empty is a value that encoded nothing. Keeping them apart is what
    /// answers "has a container already been handed out here" without a stack of containers and a
    /// depth to compare it against.
    ///
    /// Like ``PropertyListValueDecoder/_Decoder``, it points back at the node it came from rather
    /// than carrying the path to it, so `codingPath` costs nothing until an error asks for it.
    class _Encoder {
        /// The value written through the single value container, if that is what this node encoded
        /// to.
        var singleValue: PropertyListValue?
        /// The array written through an unkeyed container, if that is what this node encoded to.
        var array: PropertyListFuture.RefArray?
        /// The dictionary written through a keyed container, if that is what this node encoded to.
        var dictionary: PropertyListFuture.RefDictionary?

        /// The encoder this one was made inside, or `nil` at the top.
        private let owner: _Encoder?
        /// Where in `owner` this node's value goes, or `nil` at the top.
        private let codingKey: (any CodingKey)?

        /// Creates an encoder for a value that goes into `owner` under `codingKey`.
        init(owner: _Encoder?, codingKey: (any CodingKey)?) {
            self.owner = owner
            self.codingKey = codingKey
        }

        /// The value this node encoded to, emptying it.
        ///
        /// Emptying matters for ``PropertyListValueEncoder/_ReferencingEncoder``, which reads its
        /// own value out during `deinit` and must not be left holding a container that its parent
        /// now owns.
        func takeValue() -> PropertyListValue? {
            if let dictionary {
                self.dictionary = nil

                return .dictionary(dictionary.values)
            }

            if let array {
                self.array = nil

                return .array(array.values)
            }

            defer { singleValue = nil }

            return singleValue
        }

        /// An encoder for something inside this one.
        ///
        /// Also what carries the coding path down: a nested container needs a node to hang its key
        /// off, and this is that node.
        func encoder(forKey key: (any CodingKey)?) -> _Encoder {
            _Encoder(owner: self, codingKey: key)
        }

        /// The keys leading to this node, outermost first.
        ///
        /// Built by walking the chain of owners each time it is asked for, which only an error
        /// does.
        var codingPath: [any CodingKey] {
            var path = [any CodingKey]()
            var encoder = self as _Encoder?

            while let current = encoder {
                if let key = current.codingKey {
                    path.append(key)
                }

                encoder = current.owner
            }

            return path.reversed()
        }

        /// The path to a value written under a key inside this node, or this node's own path with
        /// no key.
        func codingPath(forKey key: (any CodingKey)?) -> [any CodingKey] {
            guard let key else { return codingPath }

            return codingPath + [key]
        }
    }
}

// MARK: - Encoder

extension PropertyListValueEncoder._Encoder: Encoder {
    /// Always empty: ``PropertyListValueEncoder`` takes no user info to pass along.
    var userInfo: [CodingUserInfoKey: Any] {
        [:]
    }

    /// A keyed container writing into this node's dictionary.
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        KeyedEncodingContainer(
            PropertyListValueEncoder.KeyedContainer<Key>(encoder: self, dictionary: dictionaryStorage())
        )
    }

    /// An unkeyed container writing into this node's array.
    func unkeyedContainer() -> any UnkeyedEncodingContainer {
        PropertyListValueEncoder.UnkeyedContainer(encoder: self, array: arrayStorage())
    }

    /// The encoder itself, as the container for its one value.
    ///
    /// Folded into the encoder rather than given a type of its own, the way Foundation's coders do
    /// it: a single value container writes exactly the one value this node stands for.
    func singleValueContainer() -> any SingleValueEncodingContainer {
        self
    }

    /// The dictionary this node encodes to, made on the first ask and returned on any later one.
    private func dictionaryStorage() -> PropertyListFuture.RefDictionary {
        if let dictionary { return dictionary }

        precondition(
            singleValue == nil && array == nil,
            "Attempt to encode a keyed container where a value has already been encoded."
        )

        let dictionary = PropertyListFuture.RefDictionary()
        self.dictionary = dictionary

        return dictionary
    }

    /// The array this node encodes to, made on the first ask and returned on any later one.
    private func arrayStorage() -> PropertyListFuture.RefArray {
        if let array { return array }

        precondition(
            singleValue == nil && dictionary == nil,
            "Attempt to encode an unkeyed container where a value has already been encoded."
        )

        let array = PropertyListFuture.RefArray()
        self.array = array

        return array
    }
}

// MARK: - Wrapping

extension PropertyListValueEncoder._Encoder {
    /// The property list value for a `Bool`.
    func wrapBool(_ value: Bool) -> PropertyListValue {
        .bool(value)
    }

    /// The property list value for a `String`.
    func wrapString(_ value: String) -> PropertyListValue {
        .string(value)
    }

    /// Widens into the one real the format has. Both `Float` and `Double` land there, and a `Float`
    /// converts back out of it exactly.
    func wrapFloatingPoint<T>(_ value: T) -> PropertyListValue where T: BinaryFloatingPoint {
        .real(Double(value))
    }

    /// Keeps one spelling per number: ``PropertyListValue/unsignedInteger`` is used only where
    /// `Int64` cannot hold the value, so two values that are the same number compare equal.
    ///
    /// Nothing a container can hand it fails both carriers — the widest is `UInt64`, and `Int128`
    /// never arrives because the standard library's own `SingleValueEncodingContainer` default
    /// refuses it before this is reached. The throw is what keeps that true if the value model ever
    /// grows a wider case, rather than something silently losing its top half.
    func wrapInteger<T>(
        _ value: T,
        forKey key: (any CodingKey)? = nil
    ) throws -> PropertyListValue where T: FixedWidthInteger {
        if let value = Int64(exactly: value) {
            return .integer(value)
        }

        if let value = UInt64(exactly: value) {
            return .unsignedInteger(value)
        }

        throw EncodingError.invalidValue(
            value,
            EncodingError.Context(
                codingPath: codingPath(forKey: key),
                debugDescription: "\(value) is wider than a property list number."
            )
        )
    }

    /// The value for one of the types written without asking it to encode itself, or `nil` for
    /// every other type.
    ///
    /// `Date` and `Data` are settled here rather than left to their own `Encodable` conformances,
    /// which would write the number and the bytes those encode to. A property list stores both
    /// natively, which is what keeps a stored date legible to `defaults(1)`.
    ///
    /// ``PropertyListValue`` is settled here because it is already the answer. Its `Encodable`
    /// conformance would come to the same value — every case has a container call that writes it
    /// back as that case — but only by standing up an encoder and a container for every node in
    /// the tree, where handing the value over costs nothing.
    ///
    /// Asked of the type rather than by casting the value, the way the decoder's
    /// ``PropertyListValueDecoder/unwrap(_:as:in:forKey:)`` asks it, so that a value of any other
    /// type is never cast at all.
    private func nativeValue<T>(of value: T) -> PropertyListValue? where T: Encodable {
        if T.self == PropertyListValue.self {
            // Safe: the branch is only entered when `T` is `PropertyListValue`.
            return (value as! PropertyListValue)
        }

        if T.self == Date.self {
            // Safe: the branch is only entered when `T` is `Date`.
            return .date(value as! Date)
        }

        if T.self == Data.self {
            // Safe: the branch is only entered when `T` is `Data`.
            return .data(value as! Data)
        }

        return nil
    }

    /// Encodes a value found inside this one.
    func wrap<T>(_ value: T, forKey key: (any CodingKey)?) throws -> PropertyListValue where T: Encodable {
        if let value = nativeValue(of: value) {
            return value
        }

        let encoder = encoder(forKey: key)
        try value.encode(to: encoder)

        // A value that asked for no container encoded nothing, which is not an error anywhere but
        // at the top: Foundation stands the same case up as an empty dictionary.
        return encoder.takeValue() ?? .dictionary([:])
    }

    /// Encodes the value this encoder was made for.
    ///
    /// Unlike ``wrap(_:forKey:)`` this writes into `self` rather than a child, which is what lets a
    /// top-level fragment work: there is no container to require, only a value to end up with.
    func wrapTopLevel<T>(_ value: T) throws -> PropertyListValue where T: Encodable {
        if let value = nativeValue(of: value) {
            return value
        }

        try value.encode(to: self)

        guard let value = takeValue() else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Top-level \(T.self) did not encode any values."
                )
            )
        }

        return value
    }
}
