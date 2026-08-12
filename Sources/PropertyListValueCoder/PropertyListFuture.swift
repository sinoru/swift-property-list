//
//  PropertyListFuture.swift
//  PropertyListValueCoder
//

import PropertyListValue

/// A ``PropertyListValue`` that is still being built.
///
/// ``PropertyListValue`` is a value type, so a container handed out early cannot be filled in later
/// — a nested dictionary appended to its parent would be a copy, and everything written into it
/// afterwards would go nowhere. `Encoder` hands containers out early by design, so the tree has to
/// be made of references while it is under construction and turned into values once at the end.
///
/// This is the shape `JSONEncoder` uses for the same reason, and the reason it needs no Objective-C
/// types to do it. Foundation solves the same problem twice: `PropertyListEncoder`, which serializes
/// and therefore ships everywhere, builds a format-specific reference tree, while the internal
/// encoder that produces property list *objects* — the one this would otherwise be — reaches for
/// `NSMutableDictionary` and is compiled only into the Darwin framework as a result. Neither is
/// reachable from here, and only one of them could have been copied.
enum PropertyListFuture {
    case value(PropertyListValue)
    case nestedArray(RefArray)
    case nestedDictionary(RefDictionary)

    /// The finished value, built by walking whatever is underneath.
    var value: PropertyListValue {
        switch self {
        case .value(let value):
            value
        case .nestedArray(let array):
            .array(array.values)
        case .nestedDictionary(let dictionary):
            .dictionary(dictionary.values)
        }
    }

    final class RefArray {
        private(set) var array = [PropertyListFuture]()

        var count: Int {
            array.count
        }

        var values: [PropertyListValue] {
            array.map(\.value)
        }

        func append(_ value: PropertyListValue) {
            array.append(.value(value))
        }

        /// Takes a position now for a value that arrives later, and answers which one it took.
        ///
        /// `superEncoder()` hands out an encoder that has no value until it is released, so the
        /// position it will occupy has to be settled before then. Taking the position — rather than
        /// remembering what `count` was and inserting there on release — is what makes two
        /// outstanding encoders land in the order they were asked for whatever order they are
        /// released in, and what lets ``count`` and the coding path see the element in the meantime.
        ///
        /// The stand-in is the empty dictionary a superclass that stored nothing reads back as, so
        /// a reservation that somehow outlives the encoding says the same thing as an unused one.
        func reserve() -> Int {
            array.append(.value(.dictionary([:])))

            return array.count - 1
        }

        /// Fills a position taken by ``reserve()``.
        func fill(_ value: PropertyListValue, at index: Int) {
            array[index] = .value(value)
        }

        func appendArray() -> RefArray {
            let array = RefArray()
            self.array.append(.nestedArray(array))

            return array
        }

        func appendDictionary() -> RefDictionary {
            let dictionary = RefDictionary()
            array.append(.nestedDictionary(dictionary))

            return dictionary
        }
    }

    final class RefDictionary {
        private(set) var dictionary = [String: PropertyListFuture]()

        var values: [String: PropertyListValue] {
            dictionary.mapValues(\.value)
        }

        func set(_ value: PropertyListValue, for key: String) {
            dictionary[key] = .value(value)
        }

        /// The array under a key, made if it is not there yet.
        ///
        /// Asking twice for the same key returns the same container, which is what lets a type write
        /// into a nested container it asked for earlier. Anything else already under that key is a
        /// caller error rather than something to paper over: overwriting it would drop a value that
        /// was encoded successfully, and do it silently. Both of the other kinds are refused, the
        /// way Foundation's own encoder refuses them.
        func setArray(for key: String) -> RefArray {
            switch dictionary[key] {
            case .nestedArray(let array):
                return array
            case .nestedDictionary:
                preconditionFailure(
                    "Attempt to encode an unkeyed container for key \"\(key)\", which already holds a keyed one."
                )
            case .value:
                preconditionFailure(
                    "Attempt to encode an unkeyed container for key \"\(key)\", which already holds a value."
                )
            case .none:
                let array = RefArray()
                dictionary[key] = .nestedArray(array)

                return array
            }
        }

        func setDictionary(for key: String) -> RefDictionary {
            switch dictionary[key] {
            case .nestedDictionary(let dictionary):
                return dictionary
            case .nestedArray:
                preconditionFailure(
                    "Attempt to encode a keyed container for key \"\(key)\", which already holds an unkeyed one."
                )
            case .value:
                preconditionFailure(
                    "Attempt to encode a keyed container for key \"\(key)\", which already holds a value."
                )
            case .none:
                let dictionary = RefDictionary()
                self.dictionary[key] = .nestedDictionary(dictionary)

                return dictionary
            }
        }
    }
}
