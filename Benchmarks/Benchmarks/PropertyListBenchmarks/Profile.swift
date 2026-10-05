//
//  Profile.swift
//  PropertyListBenchmarks
//

/// A value with no property-list form of its own, which an encoder therefore has to turn into one.
///
/// The same shape as the fixture the tests use, which is `package` there and so out of reach from
/// here: a dictionary, a nested array, and a string that is not the same length as its key.
struct Profile: Codable, Sendable {
    /// The person's name.
    var name: String
    /// The person's age.
    var age: Int
    /// The person's tags.
    var tags: [String]
    /// A name the person may also go by.
    var nickname: String?
}
