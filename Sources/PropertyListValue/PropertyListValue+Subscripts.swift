//
//  PropertyListValue+Subscripts.swift
//  PropertyList
//

extension PropertyListValue {
    /// The value stored for a key, or `nil` if this is not a dictionary or has no such key.
    ///
    /// Those two answers are deliberately the same one. A caller walking a tree it did not write —
    /// which is the reason to hold a `PropertyListValue` rather than a `Decodable` type — is asking
    /// whether the value it wants is there, and a wrong shape and a missing key both mean it is not.
    /// Anything that needs to tell them apart matches on ``dictionary`` first.
    ///
    /// Assigning `nil` removes the key: absence is the one thing a property list dictionary can say
    /// about a value it does not hold, since the format has no null.
    ///
    /// Assigning through a value that is not a dictionary replaces it with one holding just that
    /// key. There is no other reading of the assignment that keeps the value being assigned, and
    /// refusing it would mean trapping on an expression that looks total.
    @inlinable
    public subscript(key: String) -> PropertyListValue? {
        get {
            dictionary?[key]
        }
        set {
            var dictionary = self.dictionary ?? [:]
            dictionary[key] = newValue
            self = .dictionary(dictionary)
        }
    }

    /// The value stored for a key, or a default when there is none.
    @inlinable
    public subscript(
        key: String,
        default defaultValue: @autoclosure () -> PropertyListValue
    ) -> PropertyListValue {
        self[key] ?? defaultValue()
    }

    /// The element at an index, or `nil` if this is not an array or has no such index.
    ///
    /// Bounds-checked rather than trapping, and read-only. Both follow from what an index means
    /// here: unlike a key, it is a question about a value the caller has not seen the shape of, so
    /// an out-of-range one is an answer rather than a programmer error — and there is no position
    /// for an assignment to create, the way a key creates itself.
    @inlinable
    public subscript(index: Int) -> PropertyListValue? {
        guard let array, array.indices.contains(index) else { return nil }
        return array[index]
    }
}
