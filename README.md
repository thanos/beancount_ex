# beancount_ex

[![CI](https://github.com/beancount-ex/beancount_ex/actions/workflows/ci.yml/badge.svg)](https://github.com/beancount-ex/beancount_ex/actions/workflows/ci.yml)

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
              Engine.CLI (v0.1)            Engine.Elixir / Engine.Rust (future)
```

## Installation

```elixir
def deps do
  [
    {:beancount_ex, "~> 0.2"},
    # optional: enables Beancount.Explorer.to_dataframe/1
    {:explorer, "~> 0.9"}
  ]
end
```

To run checks and queries you also need Beancount installed (only required at
runtime for `Beancount.check/1`, `Beancount.query/2` and friends):

```bash
pip install beancount
```

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

# Query (BQL) and reports
{:ok, result} = Beancount.query(ledger, "SELECT account, sum(position) GROUP BY account")
{:ok, balances} = Beancount.balances(ledger)

# Optional: turn a result into an Explorer.DataFrame (renders in Livebook)
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

- [Getting Started](guides/getting_started.md)
- [Rendering](guides/rendering.md)
- [Engines](guides/engines.md)
- [Querying](guides/querying.md)
- [Reporting](guides/reporting.md)
- [Golden Files](guides/golden_files.md)
- [Property Testing](guides/property_testing.md)
- [Oracle Strategy](guides/oracle_strategy.md)
- Livebook: [Getting Started](guides/livebook/getting_started.livemd), [Reporting](guides/livebook/reporting.livemd)

## License

Released under the [MIT License](LICENSE).
