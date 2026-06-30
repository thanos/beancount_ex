# Getting Started

`beancount_ex` provides an idiomatic Elixir API for building, rendering and
checking [Beancount](https://beancount.github.io/) ledgers.

## Install

Add the dependency:

```elixir
def deps do
  [
    {:beancount_ex, "~> 0.3"}
  ]
end
```

For checking (not just rendering) you also need the Beancount toolchain:

```bash
pip install beancount
```

## Build a ledger

Constructors live directly on the `Beancount` module. You do not need to touch
the internal `Beancount.Directives` namespace.

```elixir
ledger = [
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
  Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
    Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
    Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
  ])
]
```

Amounts are always `Decimal` values, dates are `Date` structs, and accounts and
commodities are plain strings.

## Render

```elixir
Beancount.render(ledger)
```

Rendering is **deterministic**: the same directive stream always produces
byte-identical output.

## Check

```elixir
case Beancount.check(ledger) do
  {:ok, result} -> result.status      # => :ok
  {:error, result} -> result.normalized.errors
end
```

`Beancount.check/1` renders the ledger and validates it through the configured
engine. You can also validate existing content:

```elixir
Beancount.check_text("2026-01-01 open Assets:Bank USD\n")
Beancount.check_file("ledger.bean")
```

## Next steps

- [Rendering](rendering.md) - how directives become `.bean` text.
- [Engines](engines.md) - swapping the execution backend.
- [Golden Files](golden_files.md) - regression testing.
- [Property Testing](property_testing.md) - generative testing.
- [Oracle Strategy](oracle_strategy.md) - the long game.
