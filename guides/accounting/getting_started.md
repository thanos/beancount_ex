# Getting started

`beancount_ex` lets you build [Beancount](https://beancount.github.io/) ledgers
as typed Elixir data, render deterministic `.bean` text, validate entries, and
run reports. This guide is the entry point for the **accounting** track; see
[Library guides](../library.md) for parser and engine internals.

## Install

```elixir
def deps do
  [
    {:beancount_ex, "~> 0.4"},
    # optional: Explorer DataFrames for report tables in Livebook or Phoenix
    {:explorer, "~> 0.11"}
  ]
end
```

Validation and BQL reports require either:

- the Beancount toolchain (`pip install beancount beanquery`), using the default
  `Beancount.Engine.CLI`, or
- the native engine (`config :beancount_ex, engine: Beancount.Engine.Elixir`),
  which implements booking, balance assertions, and canned reports without
  shelling out.

## Build a ledger

Constructors live on the `Beancount` module. Amounts are `Decimal`, dates are
`Date`, accounts and commodities are strings.

```elixir
ledger = [
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
  Beancount.open(~D[2026-01-01], "Equity:Opening", ["USD"]),
  Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
    Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
    Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
  ])
]
```

## Render

```elixir
Beancount.render(ledger)
```

Rendering is deterministic: the same directive list always produces
byte-identical output.

## Check

```elixir
case Beancount.check(ledger) do
  {:ok, result} -> result.status
  {:error, result} -> result.normalized.errors
end
```

You can also validate existing text or files:

```elixir
Beancount.check_text("2026-01-01 open Assets:Bank USD\n")
Beancount.check_file("ledger.bean")
```

## Parse and round-trip

Import `.bean` text from disk or user input:

```elixir
{:ok, directives} = Beancount.parse_text(bean_text)
Beancount.render(directives) == bean_text  # after normalization
```

## Next steps

- [In context](in_context.md) - motivation and how pieces fit together
- [Cookbook](cookbook.md) - real-world transaction patterns
- [Running reports](running_reports.md) - balances and statements for your UI
