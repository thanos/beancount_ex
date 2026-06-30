# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
  including a placeholder `Beancount.Property.compare/2` for future oracle
  comparison.
- Documentation: README, guides, and HexDocs-ready module docs with doctests.
- GitHub Actions CI running format, compile (warnings as errors), Credo,
  Dialyzer, tests, property tests and docs.

[Unreleased]: https://github.com/beancount-ex/beancount_ex/compare/v0.1.0-pre...HEAD
[0.1.0-pre]: https://github.com/beancount-ex/beancount_ex/releases/tag/v0.1.0-pre
