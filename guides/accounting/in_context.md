# Accounting in context

This guide mirrors
[Command-line Accounting in Context](https://beancount.github.io/docs/command_line_accounting_in_context/)
but describes how to achieve the same outcomes with `beancount_ex` in an Elixir
application.

## What accounting gives you

Double-entry bookkeeping answers recurring questions:

| Question | Report / tool |
|----------|----------------|
| Where did my money go this month? | Income statement |
| What am I worth right now? | Balance sheet (net worth) |
| What do I hold in each brokerage? | Holdings report |
| Does this account reconcile? | Journal + balance assertions |
| Can I file taxes from my data? | Income statement by tax year accounts |

`beancount_ex` does not replace your bank. It gives you a **single integrated
ledger** in Elixir that you can render, validate, and query.

## The core activity: bookkeeping

Bookkeeping means recording every financial movement between **accounts** you
define. Each transaction must balance to zero: every posting has a matching
offset.

In Beancount text:

```beancount
2026-05-23 * "CAFE" "Dinner"
  Liabilities:Card    -45.00 USD
  Expenses:Restaurant
```

In Elixir:

```elixir
Beancount.transaction(~D[2026-05-23], "*", "CAFE", "Dinner", [
  Beancount.posting("Liabilities:Card", Decimal.new("-45.00"), "USD"),
  Beancount.posting("Expenses:Restaurant", nil, nil)
])
```

The elided `Expenses:Restaurant` amount is inferred at check time so the
transaction balances.

Account names use five top-level types: `Assets`, `Liabilities`, `Income`,
`Expenses`, and `Equity`. Colons separate hierarchy levels
(`Assets:US:Bank:Checking`).

## Generating reports

Once transactions are in a ledger, reports aggregate positions:

```elixir
{:ok, balances} = Beancount.balances(ledger)
{:ok, sheet} = Beancount.balance_sheet(ledger)
{:ok, income} = Beancount.income_statement(ledger)
{:ok, holdings} = Beancount.holdings(ledger)
{:ok, journal} = Beancount.journal(ledger, "Assets:Bank")
```

Each returns a `Beancount.Query.Result` with `columns` and `rows` suitable for
tables in a UI. See [Running reports](running_reports.md).

With the optional [Explorer](https://hexdocs.pm/explorer) dependency:

```elixir
df = Beancount.Explorer.to_dataframe(balances)
```

## How the pieces fit in an app

A typical Elixir accounting UI pipeline:

```
User action / import
       │
       ▼
Beancount.transaction/6, posting/4, open/4, …
       │
       ▼
[directive structs]  ──►  Beancount.render/1  ──►  .bean file / export
       │
       ▼
Beancount.check/1  ──►  validation errors for the UI
       │
       ▼
Beancount.balances/1, income_statement/1, …  ──►  dashboards
```

1. **Capture** - build directives from forms, CSV importers, or LLM output.
2. **Validate** - `check/1` before persisting; surface `result.normalized.errors`.
3. **Persist** - store directive lists (e.g. in a database as JSON) or rendered text.
4. **Report** - run canned queries or custom BQL via `Beancount.query/2`.

## Why a library instead of only `.bean` files?

- **Type safety** - structs and `Decimal` catch mistakes at compile time.
- **Composition** - generate payroll, imports, or projections from Elixir code.
- **Testing** - property tests and golden files on rendered output.
- **Engine swap** - same API with CLI oracle today, native engine tomorrow.

## Custom scripting

Upstream Beancount uses Python plugins. In `beancount_ex` you script in Elixir:

```elixir
ledger
|> Enum.filter(&match?(%Beancount.Directives.Transaction{}, &1))
|> Enum.map(fn txn -> update_transaction(txn, &tag_restaurant/1) end)
|> Beancount.check()
```

Parse existing files for batch transforms:

```elixir
{:ok, directives} = Beancount.parse_file("legacy.bean")
```

## When to read upstream docs

The Beancount project docs cover syntax edge cases, tolerances, booking methods,
and import tooling in depth. Use this library's [Cookbook](cookbook.md) for
Elixir equivalents of common patterns; follow upstream for accounting theory you
are unsure about.

## Next

- [Cookbook](cookbook.md) - account naming, cash, salary, investments
- [Running reports](running_reports.md) - wiring reports into a UI
