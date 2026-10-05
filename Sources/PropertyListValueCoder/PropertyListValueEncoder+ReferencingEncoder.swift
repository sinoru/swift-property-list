//
//  PropertyListValueEncoder+ReferencingEncoder.swift
//  PropertyListValueCoder
//

import PropertyListValue

extension PropertyListValueEncoder {
    /// The encoder `superEncoder()` hands out.
    ///
    /// A superclass is written through an encoder of its own, and nothing tells that encoder when
    /// the superclass is finished with it — so the only moment it is known to be done is when it is
    /// released. It keeps its own storage and writes it into the container it came from in `deinit`,
    /// which is how both of Foundation's coders solve the same problem.
    ///
    /// The position it writes to is taken when it is made, not when it is released — and in an
    /// array it is reserved there rather than merely remembered, so that two outstanding encoders
    /// hold two positions instead of racing for one. Anything the caller encodes in between lands
    /// after both, which is the order it asked for.
    final class _ReferencingEncoder: _Encoder {
        /// Where the encoded value goes once the encoder is released.
        private enum Reference {
            /// A position in an array, reserved when the encoder was made.
            case array(PropertyListFuture.RefArray, Int)
            /// A key in a dictionary.
            case dictionary(PropertyListFuture.RefDictionary, String)
        }

        /// The container this encoder writes into on release, and where in it.
        private let reference: Reference

        /// Creates an encoder whose value lands in a dictionary under a key.
        init(owner: _Encoder, key: any CodingKey, wrapping dictionary: PropertyListFuture.RefDictionary) {
            reference = .dictionary(dictionary, key.stringValue)

            super.init(owner: owner, codingKey: key)
        }

        /// Creates an encoder whose value lands in an array, at a position already reserved for it.
        init(owner: _Encoder, at index: Int, wrapping array: PropertyListFuture.RefArray) {
            reference = .array(array, index)

            super.init(owner: owner, codingKey: PropertyListCodingKey.index(index))
        }

        /// Writes whatever was encoded into the container this encoder came from.
        deinit {
            // A superclass that stored nothing asked for no container, and an empty dictionary is
            // what it reads back as — the same stand-in ``PropertyListValueEncoder/_Encoder/wrap(_:forKey:)``
            // uses, and what the decoder's `superDecoder()` invents when the key is absent.
            let value = takeValue() ?? .dictionary([:])

            switch reference {
            case .array(let array, let index):
                array.fill(value, at: index)
            case .dictionary(let dictionary, let key):
                dictionary.set(value, for: key)
            }
        }
    }
}
