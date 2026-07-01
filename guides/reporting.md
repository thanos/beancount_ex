# Reporting

`Beancount.Report` provides ready-made reports on top of
[querying](querying.md). Each helper generates a canned BQL query, runs it
through the configured engine, and returns a `Beancount.Query.Result`.

A `ledger` argument may be a list of directives (rendered first) or raw `.bean`
text.

## Available reports

```elixir
{:ok, result} = Beancount.balances(ledger)          # all accounts
{:ok, result} = Beancount.balance_sheet(ledger)     # Assets/Liabilities/Equity
{:ok, result} = Beancount.income_statement(ledger)  # Income/Expenses
{:ok, result} = Beancount.holdings(ledger)          # unit + cost in Assets
{:ok, result} = Beancount.journal(ledger, "Assets:Bank")
```

These are thin delegations to `Beancount.Report.balances/1` and friends, so you
can call either `Beancount.balances/1` or `Beancount.Report.balances/1`.

## Working with results

`Beancount.Query.Result.to_maps/1` turns a result into a list of column-keyed
maps:

```elixir
{:ok, result} = Beancount.balances(ledger)
Beancount.Query.Result.to_maps(result)
# => [%{"account" => "Assets:Bank", "balance" => "5000 USD"}, ...]
```

## Explorer / DataFrames (optional)

If the optional [Explorer](https://hexdocs.pm/explorer) dependency is present,
`Beancount.Explorer.to_dataframe/1` converts a result into an
`Explorer.DataFrame`:

```elixir
{:ok, result} = Beancount.balances(ledger)
df = Beancount.Explorer.to_dataframe(result)
```

In Livebook a returned `Explorer.DataFrame` renders automatically as an
interactive table. See the
[reporting notebook](livebook/reporting.livemd). Explorer `~> 0.11` is an
optional dependency: the library installs and runs without it, and the bridge
module only compiles when Explorer is available.
