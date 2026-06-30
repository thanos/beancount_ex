# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/beancount-ex/beancount_ex/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/beancount-ex/beancount_ex/compare/v0.1.0-pre...v0.2.0
[0.1.0-pre]: https://github.com/beancount-ex/beancount_ex/releases/tag/v0.1.0-pre
