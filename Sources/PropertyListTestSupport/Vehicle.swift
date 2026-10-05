//
//  Vehicle.swift
//  PropertyListTestSupport
//

/// A class with a subclass, for the half of `Codable` that structures never reach.
///
/// A subclass that keeps keys of its own writes its superclass through `superEncoder()` and reads
/// it back through `superDecoder()`, and both land on a key — `super` — that no `CodingKey` the
/// caller wrote names. Two coders that are to read each other's output have to agree on that key,
/// and this pair is what asks them to.
package class Vehicle: Codable {
    /// What sort of vehicle this is, which is the superclass's to store.
    package var kind: String

    /// Creates a vehicle of the given kind.
    package init(kind: String) {
        self.kind = kind
    }
}

/// A ``Vehicle`` with a property of its own, written beside its superclass's half.
package final class Car: Vehicle {
    /// How many doors the car has, which is the subclass's to store.
    package var doors: Int

    /// The keys the subclass writes its own properties under.
    private enum CodingKeys: String, CodingKey {
        /// The key for `doors`.
        case doors
    }

    /// Creates a car of the given kind with the given number of doors.
    package init(kind: String, doors: Int) {
        self.doors = doors

        super.init(kind: kind)
    }

    /// Reads the subclass's own key, then the superclass through `superDecoder()`.
    package required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        doors = try container.decode(Int.self, forKey: .doors)

        try super.init(from: container.superDecoder())
    }

    /// Writes the subclass's own key, then the superclass through `superEncoder()`.
    package override func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(doors, forKey: .doors)

        try super.encode(to: container.superEncoder())
    }
}
