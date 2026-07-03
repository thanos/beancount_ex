# Queries

`beancount_ex` provides two query paths:

1. **Canned reports** via `Beancount.Report` — dispatch through the configured
   engine. With `Engine.CLI`, these run as BQL via `bean-query`. With
   `Engine.Elixir`, they run natively through the booking engine.
2. **Ecto.Query** via `Beancount.Queries` — run directly against the database
   tables. No booking engine required. Use for listing, filtering, and simple
   aggregations of raw directives.

## Canned reports

```elixir
{:ok, balances} = Beancount.balances(ledger)
{:ok, sheet} = Beancount.balance_sheet(ledger)
{:ok, income} = Beancount.income_statement(ledger)
{:ok, holdings} = Beancount.holdings(ledger)
{:ok, journal} = Beancount.journal(ledger, "Assets:Bank")
```

Each returns a `Beancount.Query.Result` with `columns` and `rows`. These
reports need the booking engine (for inventory-aware balances and cost basis).

For BQL queries beyond the canned set, use `Engine.CLI` (shells out to
`bean-query`):

```elixir
{:ok, result} = Beancount.query(ledger, "SELECT account, sum(position) GROUP BY account")
```

## Ecto.Query

For ad-hoc queries against stored directives, use `Beancount.Queries`:

```elixir
# Prerequisites: store directives first (Storage replaces any existing rows)
Beancount.Storage.store(directives)

# List all open directives for asset accounts
Beancount.Queries.list_opens(prefix: "Assets")

# Count transactions by date
Beancount.Queries.count_transactions_by_date()

# Find transactions with a specific payee
Beancount.Queries.find_transactions(payee: "Employer")

# List price history for a commodity
Beancount.Queries.list_prices("USD")

# List balance assertions for an account
Beancount.Queries.list_balances("Assets:Bank")

# Count directives by type
Beancount.Queries.count_by_type()
```

These queries run directly against the database via Ecto.Query — no booking
engine required. For custom queries, build your own `Ecto.Query` against the
schema modules under `Beancount.Schemas`.

## Which path to use

| Need | Use |
|------|-----|
| Account balances (after booking) | `Beancount.balances/1` |
| Balance sheet / income statement | `Beancount.balance_sheet/1` / `income_statement/1` |
| Holdings with cost basis | `Beancount.holdings/1` |
| Transaction journal for an account | `Beancount.journal/2` |
| List / filter raw directives | `Beancount.Queries` |
| Custom Ecto.Query | `Beancount.Schemas.*` + `Ecto.Query` |
| Arbitrary BQL | `Beancount.query/2` (requires `Engine.CLI` + `bean-query`) |
