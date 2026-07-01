# beancount_ex




[![Hex.pm Version](https://img.shields.io/hexpm/v/beancount_ex.svg)](https://hex.pm/packages/beancount_ex)
[![HexDocs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/beancount_ex)
[![Hex.pm License](https://img.shields.io/hexpm/l/beancount_ex.svg)](https://hex.pm/packages/beancount_ex)
[![CI](https://github.com/thanos/beancount_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/thanos/beancount_ex/actions/workflows/ci.yml)
[![Coverage](https://coveralls.io/repos/github/thanos/beancount_ex/badge.svg?branch=main)](https://coveralls.io/github/thanos/beancount_ex)


An idiomatic Elixir interface to [Beancount](https://beancount.github.io/).

> **`beancount_ex` is not a General Ledger.** It is a compatibility layer and a
> long-term *behavioral oracle* for a future native Elixir General Ledger.

`beancount_ex` lets you build Beancount directives as typed Elixir structs,
render them to deterministic `.bean` text, validate them, and run BQL queries /
reports through a configurable engine. Today that engine wraps the real
Beancount toolchain (`bean-check`, `bean-query`). Tomorrow a native Elixir (and
later Rust) engine can replace it **without changing the public API**.

## Why this library exists

A future native Elixir General Ledger needs something trustworthy to be
validated against. Beancount is a mature, battle-tested double-entry accounting
system. By wrapping it behind a stable Elixir API, `beancount_ex`:

- gives applications an idiomatic way to construct and check ledgers today, and
- becomes the **oracle** that a native engine must agree with tomorrow.

```
                 Public API: Beancount.*
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
      Directive DSL              Engine Behaviour
            │                           │
            ▼                           ▼
        Renderer               Beancount.Engine
                                        │
                        ┌───────────────┴───────────────┐
                        ▼                               ▼
              Engine.CLI (default)            Engine.Elixir (v0.5, opt-in)
```

## Installation

```elixir
def deps do
  [
    {:beancount_ex, "~> 0.5"},
    # optional: Explorer DataFrames for report tables (see guides/accounting/running_reports.md)
    {:explorer, "~> 0.11"}
  ]
end
```

To run checks and queries you also need Beancount installed (only required at
runtime for `Beancount.check/1`, `Beancount.query/2` and friends):

```bash
pip install beancount beanquery
```

`bean-check` comes from the `beancount` package; `bean-query` comes from the
separate [`beanquery`](https://github.com/beancount/beanquery) package (required
for Beancount v3 query support).

## Usage

```elixir
ledger = [
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
  Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
    Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
    Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
  ])
]

# Deterministic rendering
bean = Beancount.render(ledger)

# 2026-01-01 open Assets:Bank USD
#
# 2026-01-01 open Income:Salary USD
#
# 2026-01-31 * "Employer" "Salary"
#   Assets:Bank     5000 USD
#   Income:Salary  -5000 USD

# Validation through the configured engine
{:ok, result} = Beancount.check(ledger)

# Parse `.bean` text
{:ok, directives} = Beancount.parse_text(bean)

# Query (BQL) and reports
{:ok, result} = Beancount.query(ledger, "SELECT account, sum(position) GROUP BY account")
{:ok, balances} = Beancount.balances(ledger)
{:ok, income} = Beancount.income_statement(ledger)

# Optional: Explorer DataFrame (requires {:explorer, "~> 0.11"})
# df = Beancount.Explorer.to_dataframe(balances)
```

The public API is `Beancount`. There is intentionally **no** public
`BeancountEx` module and you never need to reference the internal
`Beancount.Directives` namespace.

## Configuration

```elixir
config :beancount_ex,
  engine: Beancount.Engine.CLI,
  bean_check_path: "bean-check",
  bean_query_path: "bean-query"
```

## Testing

`mix test` passes **without** Beancount installed: unit, property and
golden-file rendering tests have no external dependency.

```bash
mix test                      # unit + property + golden (no Beancount needed)
mix test --include beancount  # also runs integration tests (needs bean-check)
mix beancount.golden.update   # regenerate golden fixtures
```

## Guides

### Accounting (build a UI or ledger)

For programmers and LLMs building accounting features:

- [Accounting guides index](guides/accounting/README.md)
- [Getting started](guides/accounting/getting_started.md)
- [In context](guides/accounting/in_context.md)
- [Cookbook](guides/accounting/cookbook.md)
- [Running reports](guides/accounting/running_reports.md)
- Livebook: [Getting started](guides/livebook/getting_started.livemd), [Cookbook](guides/livebook/accounting.livemd), [Parsing](guides/livebook/parsing.livemd), [Reporting](guides/livebook/reporting.livemd)

### Library (internals and testing)

- [Library guides index](guides/library.md)
- [Parsing](guides/parsing.md), [Rendering](guides/rendering.md), [Engines](guides/engines.md)
- [Querying](guides/querying.md), [Query engine](guides/query_engine.md), [Reporting](guides/reporting.md), [Booking](guides/booking.md)
- [Directive compiler](guides/directive_compiler.md), [Golden files](guides/golden_files.md), [Property testing](guides/property_testing.md), [Oracle strategy](guides/oracle_strategy.md)

## License

Released under the [MIT License](LICENSE).
