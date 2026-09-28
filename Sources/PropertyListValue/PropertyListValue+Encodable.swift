//
//  PropertyListValue+Encodable.swift
//  PropertyList
//

extension PropertyListValue: Encodable {
    /// Writes whichever shape this holds.
    ///
    /// Unlike ``init(from:)``, nothing has to be decided here: the case says what to write, and
    /// every encoder that can write a property list has a way to write it.
    ///
    /// One limit is the encoder's rather than this type's — `PropertyListEncoder` refuses a
    /// top-level fragment, so a value that is not ``dictionary(_:)`` or ``array(_:)`` has to be
    /// wrapped in one of those before it goes in.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        case .array(let array):
            try container.encode(array)
        case .string(let string):
            try container.encode(string)
        case .data(let data):
            try container.encode(data)
        case .date(let date):
            try container.encode(date)
        case .bool(let bool):
            try container.encode(bool)
        case .integer(let integer):
            try container.encode(integer)
        case .unsignedInteger(let unsignedInteger):
            try container.encode(unsignedInteger)
        case .real(let real):
            try container.encode(real)
        }
    }
}
