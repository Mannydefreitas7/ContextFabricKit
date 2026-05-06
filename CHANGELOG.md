# Changelog

All notable changes to ContextFabricKit are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `TestCorpusLoader` downloads `.tf` corpus files from a GitHub tree URL before tests run, removing the need to commit large binary assets.
- `BibleTests` and `RegularBookTests` suites cover the full API surface (F, E, L, T, S, N) against the Syriac Peshitta (0.2) and Descartes correspondence corpora respectively.
- `cfmCacheExistsAfterLoad` test verifies the `.cfm/1` binary cache is generated after `Fabric(path:)` succeeds.

### Fixed
- `T.node(from:)` now reads `T.sectionFeatureTypes` from cfabric to cast each section label to the correct Python type (`int` vs `str`) per corpus, fixing round-trip lookups on corpora with mixed section feature types (e.g. Descartes: int volume `n`, string letter `id`).
- `EdgeFeature.from(_:)` uses `s(n)` for `OslotsFeature` and `f(n)` for regular edge features, preventing a fatal member-not-found crash when accessing `oslots` via `E["oslots"].from(_:)`.
- `EdgeFeature.to(_:)` returns `[]` for `OslotsFeature` (which has no reverse method); `EdgeFeature.bidirectional(_:)` falls back to `from(_:)`.
- `EdgeFeature.hasValues` uses the safe `.checking` accessor so it does not crash on `OslotsFeature`, which lacks a `doValues` attribute.
- `Fabric.init(path:)` catches Python `OSError` via `.throwing.dynamicallyCall` and surfaces it as `ContextFabricError.loadFailed` instead of crashing via `fatalError`.
- CI and release workflows updated: cache key now includes `cfabric`, and `make install-cfabric` runs on cache miss so the embedded interpreter has all dependencies.

## [0.1.0] — 2026-05-05

### Added
- `Fabric` — loads a cfabric corpus and exposes six namespaces mirroring the Python API.
- `FeatureNamespace` (`F`) — node feature access: `value(of:)`, `nodes(for:)`, `items()`, `frequencyList()`, `meta`.
- `EdgeNamespace` (`E`) — edge feature access: `from(_:)`, `to(_:)`, `bidirectional(_:)`, `valuesFrom(_:)`, `valuesTo(_:)`, `hasValues`.
- `LocalityNamespace` (`L`) — corpus navigation: `up(_:type:)`, `down(_:type:)`, `next(_:type:)`, `previous(_:type:)`, `intersecting(_:type:)`.
- `TextNamespace` (`T`) — text rendering and section navigation: `text(of:format:)`, `section(from:lang:)`, `node(from:lang:)`.
- `SearchNamespace` (`S`) — pattern search: `search(_:limit:sets:)`, `glean(_:)`.
- `NodesNamespace` (`N`) — node iteration and sorting: `sort(_:)`.
- `PythonRuntime.initialize(pythonHome:)` — sets `PYTHONHOME`/`PYTHONPATH` for the embedded BeeWare Python 3.13 interpreter before any `Python.import(...)` call.
- `FeatureValue` enum (`case string(String)` / `case int(Int)`) with `Sendable`, `Equatable`, and `CustomStringConvertible` conformances.
- `Makefile` targets: `bootstrap`, `download-python`, `extract`, `install-cfabric`, `sign-python`.
- CI workflow (GitHub Actions, macOS 15) with `swift build` + `swift test` on every push/PR.
- Release-please pipeline for automated semver releases from the `master` branch.
