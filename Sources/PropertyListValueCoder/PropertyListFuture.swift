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
///
/// Whatever puts a value into the tree takes it, and its key, `consuming`. What arrives is nearly
/// always something just built — the result of a nested `wrap` above all — and the tree is where
/// it stays, so a borrowed parameter would only mean copying it in and releasing the caller's copy
/// straight after. Taking it removed a retain per nested container: 20,000 of the 240,000 in
/// encoding 5,000 structures that each hold an array and a structure, and about 5% of the time.
enum PropertyListFuture {
    /// A value that is already finished.
    case value(PropertyListValue)
    /// An array still being written into.
    case nestedArray(RefArray)
    /// A dictionary still being written into.
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

    /// An array under construction, shared by reference between the containers writing into it.
    final class RefArray {
        /// The elements written so far, in the order they were written.
        private(set) var array = [PropertyListFuture]()

        /// The number of elements written so far, with the positions reserved among them.
        var count: Int {
            array.count
        }

        /// The finished array, each element built from whatever is underneath it.
        var values: [PropertyListValue] {
            array.map(\.value)
        }

        /// Adds a finished value at the end.
        func append(_ value: consuming PropertyListValue) {
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
        func fill(_ value: consuming PropertyListValue, at index: Int) {
            array[index] = .value(value)
        }

        /// Adds an empty array at the end, and returns it to be written into.
        func appendArray() -> RefArray {
            let array = RefArray()
            self.array.append(.nestedArray(array))

            return array
        }

        /// Adds an empty dictionary at the end, and returns it to be written into.
        func appendDictionary() -> RefDictionary {
            let dictionary = RefDictionary()
            array.append(.nestedDictionary(dictionary))

            return dictionary
        }
    }

    /// A dictionary under construction, shared by reference between the containers writing into it.
    final class RefDictionary {
        /// The values written so far, by key.
        ///
        /// Room for six keys from the start, which is eight buckets. A keyed container is asked
        /// for by a type about to write its properties, and an empty dictionary grows to hold them
        /// by doubling — one, three, six — hashing every key it already holds again each time.
        /// Starting at the third of those steps skips the two before it, and a type with one
        /// property measured the same either way.
        ///
        /// No further, because ``values`` hands the finished dictionary the same buckets: twelve
        /// was quicker again for a type with eight properties or more, and would have left every
        /// smaller one holding sixteen for as long as the value is kept.
        private(set) var dictionary = [String: PropertyListFuture](minimumCapacity: 6)

        /// The finished dictionary, each value built from whatever is underneath it.
        var values: [String: PropertyListValue] {
            dictionary.mapValues(\.value)
        }

        /// Stores a finished value under a key, replacing whatever was there.
        func set(_ value: consuming PropertyListValue, for key: consuming String) {
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

        /// The dictionary under a key, made if it is not there yet.
        ///
        /// The keyed counterpart of ``setArray(for:)``, and refuses the other two kinds as that
        /// does.
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
