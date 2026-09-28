# PropertyList

[![GitHub Actions — CI](https://github.com/sinoru/swift-property-list/actions/workflows/ci.yml/badge.svg)](https://github.com/sinoru/swift-property-list/actions/workflows/ci.yml)
[![GitHub Actions — Apple Platforms](https://github.com/sinoru/swift-property-list/actions/workflows/apple-platforms.yml/badge.svg)](https://github.com/sinoru/swift-property-list/actions/workflows/apple-platforms.yml)

[![Swift Package Index — Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsinoru%2Fswift-property-list%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/sinoru/swift-property-list)
[![Swift Package Index — Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsinoru%2Fswift-property-list%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/sinoru/swift-property-list)

**PropertyList** models a property list as a Swift value: an enum over the shapes the format
holds, and a `Codable` pair that reads and writes one directly. `UserDefaults` and
`PropertyListSerialization` deal in `Any`, so anything looking inside a stored value casts its
way down the tree and gets no help from the compiler on the way. This is that tree with the
casts already made.

## Table of Contents

* [Getting Started](#getting-started)
* [The Value](#the-value)
* [Reading and Writing](#reading-and-writing)
* [Encoding and Decoding](#encoding-and-decoding)
* [Platform Support](#platform-support)
* [Using PropertyList in Your Project](#using-propertylist-in-your-project)
* [Contributing](#contributing)
* [License](#license)

## Getting Started

```swift
import PropertyList

let value = try PropertyListSerialization.propertyListValue(from: data)

let name = value["Profile"]?["name"]?.string
let firstTag = value["Profile"]?["tags"]?[0]?.string
let retries = value["Retries", default: 3].integer
```

`PropertyListValue` is `Hashable` and `Sendable`, builds from literals, and bridges to and
from the `Any` that Foundation deals in. Nothing here traps: a wrong shape and a missing key
both read as `nil`, which is the question a caller walking a tree it did not write is actually
asking.

## The Value

```swift
public enum PropertyListValue: Hashable, Sendable {
    case dictionary([String: PropertyListValue])
    case array([PropertyListValue])
    case string(String)
    case data(Data)
    case date(Date)
    case bool(Bool)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case real(Double)
}
```

Three of the cases are places where the format and Swift disagree, and each is decided in
favour of the format:

* **There is no null.** A property list has no such value, so a `nil` inside one is a
  convention between an encoder and a decoder rather than something the format can carry.
  This package writes Foundation's `$null` sentinel, so a value written by
  `PropertyListEncoder` reads here and one written here reads in `PropertyListDecoder`;
  `isNull` reports whether a stored value stands for a `nil` rather than for itself.
* **`bool` is separate from `integer`.** `<true/>` and `<integer>1</integer>` are different
  values in the format, `defaults(1)` prints them differently, and a reader asking for one
  when the other is stored is asking about the writer's intent — which is only answerable
  while the two are still distinguishable.
* **`unsignedInteger` exists only for what `integer` cannot hold,** which is every value above
  `Int64.max`. Keeping it to that leaves one spelling per number, so two values that are the
  same number are also `==`.

A `Float` widens into `real` rather than taking a case of its own. Every `Float` converts to
`Double` exactly and converts back exactly, so the only difference is four bytes in a binary
property list.

## Reading and Writing

From bytes, in whichever format they are written — binary, XML, or OpenStep:

```swift
let value = try PropertyListSerialization.propertyListValue(from: data)
```

From the `Any` the defaults system hands back, and back to the one it takes:

```swift
guard let object = UserDefaults.standard.object(forKey: "Profile"),
      let value = PropertyListValue(propertyList: object) else { return }

UserDefaults.standard.set(value.propertyList, forKey: "Profile")
```

Reading bytes goes through `PropertyListSerialization.propertyListValue(from:)` rather than
through `Decodable`, and the reason is fidelity. `<real>2.0</real>` and `<integer>2</integer>`
are different documents, and `propertyListValue(from:)` keeps them apart by asking
`CFNumberIsFloatType`. A `Decoder` has no such question to ask — it says what a value can be
read *as*, never what it was written *as* — so reading the same bytes through `Decodable`
yields `integer` for both, and writing that tree back out has changed the document.

Bytes with a type to read them into want `PropertyListDecoder` and no tree in between;
`propertyListValue(from:)` is for bytes whose shape the caller does not know in advance.

Each case has an accessor that answers `nil` for every other case — `dictionary`, `array`,
`string`, `data`, `date`, `bool`, `integer`, `unsignedInteger`, `real`. Assigning through a key
creates the dictionary if there is not one, and assigning `nil` removes the key, since absence
is the only thing a property list dictionary can say about a value it does not hold.
Subscripting by index is read-only and bounds-checked: there is no position for an assignment
to create the way a key creates itself.

```swift
var profile: PropertyListValue = [
    "name": "Jane Doe",
    "age": 30,
    "tags": ["swift", "macOS"],
    "enabled": true,
]

profile["nickname"] = "Janie"
profile["age"] = nil
```

## Encoding and Decoding

`PropertyListValueEncoder` and `PropertyListValueDecoder` read and write a `PropertyListValue`
tree directly, without serializing it to `Data` and scanning it back:

```swift
let value = try PropertyListValueEncoder().encode(profile)
let decoded = try PropertyListValueDecoder().decode(Profile.self, from: value)
```

Numbers convert across integer and real at every depth, because a property list keeps no
`Float`/`Double`/`Int` distinction to hold a decoder to. Neither side has a top-level fragment
restriction: a single `String` encodes as a `PropertyListValue` on its own, with no
single-element array to get past.

`PropertyListValue` is itself `Codable`, so it can sit inside any other `Codable` type as a
field whose shape is not known in advance.

## Platform Support

The package supports macOS 12, Mac Catalyst 15, iOS 15, tvOS 15, watchOS 8, and visionOS 1 or
later, along with every platform Foundation builds for. Away from Apple platforms the bridge to
Foundation's `Any` sits behind a trait of its own — see
[Using PropertyList in Your Project](#using-propertylist-in-your-project). The one other thing
that differs is how a number arriving as an `Any` is told apart: Darwin hands
every number back as an `NSNumber`, booleans included, so the CoreFoundation type ID is what
separates `bool` from `integer` and `real` from both, while swift-corelibs-foundation unboxes
before returning and the Swift type it chose is enough.

Building the package requires Swift 6.3 or later.

### Running the tests

`swift test` needs no arguments and takes no environment variables.

The one thing a plain run leaves out is the measurements, which a debug build skips because an
unoptimized one says nothing. No documentation above quotes them and no API here was chosen on
them: they hold this package's coder against the `Data` round trip it replaced, and the two ways
from bytes to a `PropertyListValue` against each other. Read the numbers; nothing there fails on
a regression, because a number means something next to the number beside it rather than next to
one from another machine.

```sh
swift test -c release --filter PerformanceTests
```

No `-enable-testing`: nothing there needs a `@testable import`, and asking for one would
publish the internal symbols of the very module being timed. Both measurement suites are
Darwin-only, since `measure(metrics:)` is — swift-corelibs-xctest has no equivalent to call.

## Using PropertyList in Your Project

To use this package in a SwiftPM project, add the following to your `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/sinoru/swift-property-list.git",
        "0.0.1"..<"0.1.0"
    ),
]
```

Then add `PropertyList` as a dependency of your target:

```swift
.target(
    name: "MyTarget",
    dependencies: [
        .product(name: "PropertyList", package: "swift-property-list"),
    ]
),
```

The value and the coder each live behind a
[package trait](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md)
of the same name, both enabled by default. A consumer that only reads a property list can
leave the coder out:

```swift
.package(
    url: "https://github.com/sinoru/swift-property-list.git",
    "0.0.1"..<"0.1.0",
    traits: ["Value"]
),
```

`Value` provides `PropertyListValue` and its accessors. `ValueCoder` provides
`PropertyListValueEncoder` and `PropertyListValueDecoder`, and enables `Value` with it, since
both coders read and write that type. The split is by size: the value and its accessors are a
few hundred lines, and the coder pair is several times that.

`ValueFoundation` provides the bridge to Foundation's `Any` — `PropertyListValue(propertyList:)`,
`propertyList`, and `PropertyListSerialization.propertyListValue(from:)` — and enables `Value`
with it. It only matters away from Apple platforms, where everything else reads `Data` and
`Date` from FoundationEssentials and this is the one part that needs Foundation itself, and the
ICU that comes with it. It is off by default there; on Apple platforms Foundation is part of the
system and the bridge is always available. A consumer on Linux that wants it asks for it
alongside the defaults:

```swift
.package(
    url: "https://github.com/sinoru/swift-property-list.git",
    "0.0.1"..<"0.1.0",
    traits: [.defaults, "ValueFoundation"]
),
```

Without it, bytes are read through `PropertyListDecoder`, which FoundationEssentials provides —
at the cost of the fidelity described in [The Value](#the-value):

```swift
let value = try PropertyListDecoder().decode(PropertyListValue.self, from: data)
```

## Contributing

Bug reports, feature ideas, and pull requests are welcome on
[GitHub](https://github.com/sinoru/swift-property-list).

## License

[Apache License 2.0](LICENSE)
