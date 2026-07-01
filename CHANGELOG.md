# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Native `Ledger` now processes dated directives in Beancount date order
  (`entry_sortkey`) instead of source-file order, closing the `balance_failed`
  gap on vendored `example.beancount`.
- `Compare` normalizes position cells by merging lots at the same cost and
  trimming zero balances when comparing query output.

## [0.5.0] - 2026-06-30

Native BQL parser, directive compiler, and Datalog-style query evaluation.

### Added

- `Beancount.BQL` - parse and evaluate Beancount Query Language strings.
- Directive compiler: `FactBase`, `Index` (ETS), `CompiledLedger`, `QueryEngine`.
- Guides: `query_engine.md`, `directive_compiler.md`.
- BQL parity tests (tagged `:beancount`) and `bench/compiler_bench.exs`.
- Coveralls.io integration in CI.

### Changed

- `Engine.Elixir.query/2` evaluates arbitrary supported BQL natively (replaces
  hardcoded canned-query map).
- Reconciliation test documents known `balance_failed` gap on `example.beancount`
  instead of a skipped equivalence test.

[Unreleased]: https://github.com/beancount-ex/beancount_ex/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/beancount-ex/beancount_ex/compare/v0.4.0...v0.5.0

## [0.4.0] - 2026-06-30

Full native booking parity, reconciliation harness, and performance benchmarks.

### Added

- Native booking engine (`Inventory`, `Booking`, `Lot`) with FIFO, LIFO, STRICT,
  AVERAGE, and NONE methods.
- Balance assertion evaluation with tolerance inference (`BalanceCheck`, `Tolerance`).
- Pad resolution (`PadResolver`) with per-account pending pads.
- Option processing (`Options`) for tolerance and operating currency settings.
- Error category normalization in `Beancount.Compare.compare/3`.
- Reconciliation harness: vendored `example.beancount` and
  `test/beancount/reconciliation_test.exs`.
- Benchmarks under `bench/` and guides: `booking.md`, `reconciliation.md`,
  `performance.md`.
- Parser support for org-mode headers, multiline `query` strings, and hyphens in
  account names.

### Changed

- All 30 golden fixtures pass `compare/3` as `{:ok, :equivalent}`.
- `Ledger` processes directives in date order with point-in-time open/close checks.
- `compare/3` skips canned queries when both engines agree on equivalent check
  errors; no more `:deferred` return value.

[0.4.0]: https://github.com/beancount-ex/beancount_ex/compare/v0.3.0...v0.4.0

## [0.3.0] - 2026-06-30

Native parser, Elixir engine, and oracle comparison.

### Added

- `Beancount.Parser` with full Beancount grammar coverage (NimbleParsec).
- Public parse API: `parse/1`, `parse_text/1`, `parse_file/1`, `parse!/1`.
- New directives: `Query`, `Plugin`, `PushTag`, `PopTag` with constructors
  `query_directive/3`, `plugin/2`, `push_tag/1`, `pop_tag/1`.
- `Beancount.Engine.Elixir`: native structural `check/1` and canned `query/2`.
- `Beancount.Compare.compare/3` and `Beancount.Property.Diff` for oracle ↔
  native equivalence within the v0.3 parity contract.
- Guide: `guides/parsing.md`.

### Changed

- `Beancount.Property.compare/3` replaces the v0.2 placeholder.
- `decimal` dependency bumped to `~> 3.1` (security fix).
- `Beancount.check_file/1` routes through the configured engine.

[0.3.0]: https://github.com/beancount-ex/beancount_ex/compare/v0.2.0...v0.3.0

## [0.2.0] - 2026-06-30

Adds querying and reporting on top of the v0.1 directive/render/check core.

### Added

- `query/2` callback on the `Beancount.Engine` behaviour; native engines must
  implement it too.
- `Beancount.Query` wrapper around `bean-query` (CSV output) with a configurable
  `:bean_query_path` and `Beancount.Query.NotInstalledError`.
- Neutral, engine-independent `Beancount.Query.Result` struct with `to_maps/1`.
- Public API: `Beancount.query/2`, `query_text/2`, `query_file/2`.
- `Beancount.Report` with `balances/1`, `balance_sheet/1`, `income_statement/1`,
  `holdings/1`, `journal/2`, delegated from the `Beancount` module.
- Optional `Beancount.Explorer.to_dataframe/1` bridge (compiled only when the
  optional `:explorer` dependency is present).
- Guides: `querying.md`, `reporting.md`, and Livebook notebooks under
  `guides/livebook/`.

### Changed

- `Beancount.Engine.CLI` now implements `query/2`.

## [0.1.0-pre] - 2026-06-30

Initial pre-release establishing the compatibility layer and behavioral oracle.

### Added

- Idiomatic public API under `Beancount` for constructing directives:
  `open/4`, `close/3`, `commodity/3`, `transaction/6`, `posting/4`,
  `balance/5`, `price/5`, `note/4`, `document/4`, `event/4`, `custom/4`.
- Typed directive structs under `Beancount.Directives.*`.
- `Beancount.Directive` protocol and deterministic `Beancount.Renderer`.
- `Beancount.Engine` behaviour with the initial `Beancount.Engine.CLI`
  implementation wrapping `bean-check` via `Beancount.Checker`.
- `Beancount.Result` and `Beancount.Normalizer` for engine-independent output.
- Golden-file infrastructure (`Beancount.Golden`) and the
  `mix beancount.golden.update` task.
- Property-testing infrastructure (`Beancount.Property`) built on `StreamData`,
  including a planned oracle-comparison helper in `Beancount.Property` for
  future engine validation.
- Documentation: README, guides, and HexDocs-ready module docs with doctests.
- GitHub Actions CI running format, compile (warnings as errors), Credo,
  Dialyzer, tests, property tests and docs.

[0.2.0]: https://github.com/beancount-ex/beancount_ex/compare/v0.1.0-pre...v0.2.0
[0.1.0-pre]: https://github.com/beancount-ex/beancount_ex/releases/tag/v0.1.0-pre
