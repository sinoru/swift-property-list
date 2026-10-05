# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-10-06

### Changed

- On Apple platforms, `PropertyListValue(propertyList:)` reads what
  `PropertyListSerialization` and `UserDefaults` hand back in under a third
  of the instructions: an object is told apart once by its CoreFoundation
  type ID, a number is read without being bridged first, and a collection
  is walked where it stands rather than cast to a Swift one.
  `PropertyListSerialization.propertyListValue(from:)` takes about 58% fewer
  instructions for it, and a tree of Swift values built by hand about 6%
  fewer.
- `PropertyListValue.init(from:)` asks the decoder whether a value is a
  dictionary or an array before reading it as one, where it used to find out
  by reading a collection and failing. Reading a tree through
  `PropertyListDecoder` takes about 10% fewer instructions for it.
- `PropertyListValue.init(from:)` throws the error for something nested that
  no case can hold — a `CFKeyedArchiverUID`, say — as the decoder reported it,
  with the coding path to where it was. It used to be wrapped in a
  `dataCorrupted` at the collection that held it, with that path only in the
  message.
- `PropertyListValueDecoder` looks a key up once to read an optional property,
  where the standard library's `decodeIfPresent` looked it up three times.
  Decoding a structure with one optional property among four takes about 5%
  fewer instructions.
- `PropertyListValueEncoder` starts a dictionary with room for six keys rather
  than growing it from empty, which takes about 7% off encoding a structure of
  four properties and two allocations with it.
- On Apple platforms, the package now depends on
  [swift-core-foundation-kit](https://github.com/sinoru/swift-core-foundation-kit),
  which is what tells an object apart by its CoreFoundation type ID and
  reads it from there. Other platforms resolve the dependency and build
  none of it. It is asked for from 1.0.0, which walks a dictionary of eight
  pairs or fewer without allocating: reading an object graph takes three
  allocations fewer for it, and about 5% fewer instructions.

## [0.1.0] - 2026-09-28

### Added

- The `ValueFoundation` package trait, off by default, which brings in the bridge
  to Foundation's `Any` away from Apple platforms. On Apple platforms the bridge
  is always available.
- `PropertyListSerialization.propertyListValue(from:)`, which reads a property
  list from its bytes, in whichever format they are written, beside the
  `propertyList(from:options:format:)` it does the same job as.

### Changed

- Away from Apple platforms, the value and the coder import FoundationEssentials
  rather than Foundation, so a consumer there no longer links Foundation and the
  ICU it brings. `PropertyListValue(propertyList:)`, `propertyList`, and
  `PropertyListSerialization.propertyListValue(from:)` need Foundation itself,
  and there they now require the `ValueFoundation` trait; enable it with
  `traits: [.defaults, "ValueFoundation"]`.

### Removed

- `PropertyListValue.init(data:)`, which `propertyListValue(from:)` replaces.
  Replace `PropertyListValue(data: data)` with
  `PropertyListSerialization.propertyListValue(from: data)`.

### Fixed

- `PropertyListValue.init(from:)` reads a null — a JSON `null`, or the `$null`
  sentinel that `PropertyListDecoder` folds one into — as the sentinel, which
  `isNull` reports as a `nil`, rather than throwing `dataCorrupted`. A tree the
  package's own encoder wrote a `nil` into, or an array `PropertyListEncoder`
  wrote one into, decodes back now.
- `PropertyListValue(propertyList:)` reads an `NSArray` on WASI instead of
  returning `nil`. swift-corelibs-foundation there does not bridge one to
  `[Any]` through a cast, as it does on Linux.

## [0.0.2] - 2026-09-28

### Changed

- `PropertyListValueEncoder` writes a `PropertyListValue` it is handed as it is,
  rather than encoding the tree again node by node. The result is the same; a
  type holding a large tree in a `PropertyListValue` property encodes in time
  that no longer grows with the size of that tree.
- `PropertyListValueEncoder` moves each value it builds into the tree rather than
  copying it in, which takes about 5% off encoding types with nested containers.
- `PropertyListValueDecoder` reads a structure-heavy tree about 30% faster. The
  null check it makes before every value, `isNull`, looks at the one case that
  can hold the sentinel instead of comparing whole values.
- `PropertyListValueDecoder` reads the scalars inside an array or a dictionary
  without making a decoder for each one, which takes about 10–13% off reading
  collections of them.
- `PropertyListValueDecoder` reads a scalar at the top level without making a
  decoder for it, which takes close to 60% off decoding a single stored `Int` or
  `String`. Errors report the same empty coding path as before.

## [0.0.1] - 2026-08-16

### Added

- `PropertyListValue`, an enum over the shapes a property list can hold, bridging
  to and from the `Any` tree that `UserDefaults` and `PropertyListSerialization`
  deal in. `bool` stays distinct from `integer`, and `unsignedInteger` covers only
  what `Int64` cannot hold.
- Literal, subscript, description, and `Data` conveniences for `PropertyListValue`,
  along with its `Encodable` and `Decodable` conformances.
- `PropertyListValueEncoder` and `PropertyListValueDecoder`, a `Codable` pair that
  reads and writes a `PropertyListValue` tree directly instead of round-tripping
  through serialized bytes. Numbers convert across integer and real at every depth.
- The `Value` and `ValueCoder` package traits, both enabled by default, so a
  consumer that only reads a property list can skip the coder machinery.
- Support for macOS 12, Mac Catalyst 15, iOS 15, tvOS 15, watchOS 8, visionOS 1
  and later, along with every platform Foundation builds for. Everything is
  available everywhere. Building the package requires Swift 6.3 or later.

[unreleased]: https://github.com/sinoru/swift-property-list/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/sinoru/swift-property-list/compare/v0.1.0...v1.0.0
[0.1.0]: https://github.com/sinoru/swift-property-list/compare/v0.0.2...v0.1.0
[0.0.2]: https://github.com/sinoru/swift-property-list/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/sinoru/swift-property-list/releases/tag/v0.0.1
