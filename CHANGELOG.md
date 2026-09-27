# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- `PropertyListValueEncoder` writes a `PropertyListValue` it is handed as it is,
  rather than encoding the tree again node by node. The result is the same; a
  type holding a large tree in a `PropertyListValue` property encodes in time
  that no longer grows with the size of that tree.
- `PropertyListValueDecoder` reads a structure-heavy tree about 30% faster. The
  null check it makes before every value, `isNull`, looks at the one case that
  can hold the sentinel instead of comparing whole values.

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

[unreleased]: https://github.com/sinoru/swift-property-list/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/sinoru/swift-property-list/releases/tag/v0.0.1
