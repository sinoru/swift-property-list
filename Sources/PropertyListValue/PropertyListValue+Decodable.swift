//
//  PropertyListValue+Decodable.swift
//  PropertyList
//

import Foundation

extension PropertyListValue: Decodable {
    /// Reads whatever the decoder holds at this position, whichever of the format's shapes it is.
    ///
    /// This is what makes `PropertyListDecoder().decode(PropertyListValue.self, from: data)` work,
    /// and that call is the point of it: it reads the bytes once, in Swift, with no `NSNumber` or
    /// `NSDictionary` standing between them and the tree. ``init(propertyList:)`` is the other way
    /// in, and it starts from an `Any` that something else has already built.
    ///
    /// ## Which case a number reads as
    ///
    /// A `Decoder` says what a value can be read *as*, never what it was written *as*, and the two
    /// come apart for numbers: `PropertyListDecoder` reads an `<integer>` as a `Double` and a
    /// whole-valued `<real>` as an `Int64`, so no order of attempts can tell them apart. The order
    /// below therefore fixes an answer rather than discovering one:
    ///
    /// - `<real>2.0</real>` reads as ``PropertyListValue/integer(_:)``, not ``real(_:)``.
    /// - `<real>2.5</real>`, a NaN, and an infinity read as ``real(_:)`` — none of them survives
    ///   `Int64(exactly:)`, which is what the attempt before it comes down to.
    /// - A number above `Int64.max` reads as ``unsignedInteger(_:)``, which is why `UInt64` is
    ///   tried between the two: a `Double` attempt would take it first and round it.
    ///
    /// **This differs from ``init(propertyList:)``**, which asks `CFNumberIsFloatType` and so keeps
    /// a whole-valued `<real>` as ``real(_:)``. One property list read both ways can therefore
    /// produce two values that compare unequal. The paths do not overlap in practice — this one
    /// starts from bytes, that one from what `UserDefaults` hands back — and the alternative was
    /// giving up reading bytes directly, which is the reason this exists.
    ///
    /// `<true/>` and `<integer>1</integer>` are *not* affected: `PropertyListDecoder` refuses to
    /// read either as the other, so the distinction the format draws there survives.
    ///
    /// ## Order of the attempts, and what they cost
    ///
    /// The order is by how often a property list holds each shape, except where correctness pins
    /// it: `Int64` before `UInt64` before `Double`, for the reason above.
    ///
    /// **This is not the fast way in.** A `Decoder` offers no way to ask what a value is, only to
    /// ask for it as something, so every case but the right one costs a thrown `DecodingError` —
    /// and a value nested in a tree pays that two to six times over. Measured against
    /// ``init(propertyList:)`` on the same bytes (see `PropertyListValueReadingPerformanceTests`,
    /// instructions retired, one tree of about twenty nodes):
    ///
    /// | Bytes to tree | Instructions |
    /// | - | - |
    /// | `PropertyListDecoder` into this initializer | ~2,365,000 |
    /// | `PropertyListSerialization` into ``init(propertyList:)`` | ~282,000 |
    ///
    /// Reading the bytes in Swift is the cheaper half of the work, and the attempts more than spend
    /// what it saves. Reordering does not rescue it: the count of failed attempts per node barely
    /// moves, whichever order they are in.
    ///
    /// So this conformance is for reaching a `PropertyListValue` where a `Decoder` is what there
    /// is — a field inside another `Decodable` type, a decoder that is not Foundation's. Anything
    /// reading whole property lists for their contents wants ``init(propertyList:)``.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()

        // The container attempts are kept rather than discarded. A scalar mismatch says only that
        // this was not that case, but a container mismatch can be the report of something nested
        // that no case can hold — a bplist UID, say — and that error names where it was.
        let dictionaryError: any Error
        do {
            self = .dictionary(try container.decode([String: PropertyListValue].self))
            return
        } catch {
            dictionaryError = error
        }

        let arrayError: any Error
        do {
            self = .array(try container.decode([PropertyListValue].self))
            return
        } catch {
            arrayError = error
        }

        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let integer = try? container.decode(Int64.self) {
            self = .integer(integer)
        } else if let unsignedInteger = try? container.decode(UInt64.self) {
            self = .unsignedInteger(unsignedInteger)
        } else if let real = try? container.decode(Double.self) {
            self = .real(real)
        } else if let date = try? container.decode(Date.self) {
            self = .date(date)
        } else if let data = try? container.decode(Data.self) {
            self = .data(data)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: """
                        Not a shape a property list holds, or holding one nested inside it that is \
                        not. Read as a dictionary: \(dictionaryError). Read as an array: \
                        \(arrayError).
                        """,
                    underlyingError: dictionaryError
                )
            )
        }
    }
}
