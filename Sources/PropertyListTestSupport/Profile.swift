//
//  Profile.swift
//  PropertyListTestSupport
//
//  Created by Kang Jaehong on 7/18/26.
//

/// A value with no property-list form of its own, which an encoder therefore has to turn into one.
///
/// One property is optional so that both halves of what a synthesized `Codable` does with `nil` are
/// reachable from a single fixture: `encodeIfPresent` leaves the key out rather than writing the
/// sentinel, and `decodeIfPresent` reads a key that holds the sentinel back as `nil`. It defaults to
/// `nil` so a test that has nothing to say about it can go on ignoring it.
package struct Profile: Codable, Equatable, Sendable {
    /// The person's name.
    package var name: String
    /// The person's age, which puts a number among the strings.
    package var age: Int
    /// The person's tags, which put an array one level down.
    package var tags: [String]
    /// A name the person may also go by, and the one property that can be `nil`.
    package var nickname: String?

    /// Creates a profile, with no nickname unless one is given.
    package init(name: String, age: Int, tags: [String], nickname: String? = nil) {
        self.name = name
        self.age = age
        self.tags = tags
        self.nickname = nickname
    }
}
