//
//  PropertyListValue+Null.swift
//  PropertyList
//

extension PropertyListValue {
    /// The value a `nil` is written as.
    ///
    /// A property list has no null, so an encoder that has to write one has to stand it up as
    /// something the format does have. Foundation picked the string `$null`, and this is the same
    /// string for the same reason a decoder has to know it: a value written by
    /// `PropertyListEncoder` has to read here, and one written here has to read in
    /// `PropertyListDecoder` and anything else that goes through it.
    ///
    /// The cost of any such sentinel is that a string which genuinely is `$null` cannot be told
    /// apart from a `nil`, and this one is no exception — Foundation's own scanners fold the two
    /// together while they are still reading bytes, so `PropertyListDecoder` cannot hand that string
    /// back at all. Choosing a different sentinel would move which string is unwritable, not remove
    /// the problem, and would give up reading anything Foundation wrote.
    ///
    /// `package` rather than `public` because writing and reading the sentinel is the coder's job,
    /// and the coder ships in this package. Anyone outside it asks ``isNull`` instead of comparing.
    package static let null = PropertyListValue.string(nullString)

    /// The string ``null`` holds, for ``isNull`` to compare against without going through ``null``.
    private static var nullString: String {
        "$null"
    }

    /// Whether this stands for a `nil` rather than for itself.
    ///
    /// `public` rather than `internal` because the read path asks it of a whole stored value before
    /// decoding one: a sentinel there means the storage holds nothing, which is a question about
    /// storage rather than about coding — and the code asking it sits above this package.
    ///
    /// Matched on the case rather than compared with `==` against ``null``. The coder asks this
    /// before every value it unwraps, and the synthesized `==` of a recursive enum, reached through
    /// the stored ``null``, measured as a large share of reading a tree: going straight to the one
    /// case that can be the sentinel took about 30% off decoding a structure-heavy one.
    public var isNull: Bool {
        guard case .string(let string) = self else { return false }

        return string == Self.nullString
    }
}
