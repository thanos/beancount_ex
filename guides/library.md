# Library guides

These guides document **how `beancount_ex` is implemented**: parsing, rendering,
engines, testing, and oracle comparison. Use them when contributing to the
library or swapping execution backends.

If you are building an application or accounting UI, start with the
[Accounting guides](accounting/index.md) instead.

## Parsing and rendering

- [Parsing](parsing.md) - `Beancount.Parser`, grammar, directives
- [Rendering](rendering.md) - `Beancount.Renderer`, deterministic output

## Execution

- [Engines](engines.md) - `Beancount.Engine` behaviour, CLI vs native
- [Querying](querying.md) - BQL and `Beancount.Query`
- [Reporting](reporting.md) - `Beancount.Report` helpers

## Quality

- [Golden files](golden_files.md) - fixture regression tests
- [Property testing](property_testing.md) - generative ledgers
- [Oracle strategy](oracle_strategy.md) - long-term equivalence plan

## Livebooks

- [Getting started](livebook/getting_started.livemd)
- [Accounting cookbook](livebook/accounting.livemd)
- [Parsing and validation](livebook/parsing.livemd)
- [Reporting with Explorer](livebook/reporting.livemd)
