# Querying

`beancount_ex` can run [Beancount Query Language](https://beancount.github.io/docs/beancount_query_language.html)
(BQL) queries against a ledger through the configured engine. The CLI
engine shells out to `bean-query` from the [`beanquery`](https://github.com/beancount/beanquery)
package; future native engines implement the same `c:Beancount.Engine.query/2`
callback.

Install with: `pip install beanquery` (Beancount v3 does not bundle `bean-query`
in the `beancount` package alone).

## Running a query

All three entry points mirror the `check/*` family:

```elixir
ledger = [
  Beancount.open(~D[2026-01-01], "Assets:Bank", ["USD"]),
  Beancount.open(~D[2026-01-01], "Income:Salary", ["USD"]),
  Beancount.transaction(~D[2026-01-31], "*", "Employer", "Salary", [
    Beancount.posting("Assets:Bank", Decimal.new("5000"), "USD"),
    Beancount.posting("Income:Salary", Decimal.new("-5000"), "USD")
  ])
]

{:ok, result} =
  Beancount.query(ledger, "SELECT account, sum(position) GROUP BY account")

# raw text instead of directives
{:ok, result} = Beancount.query_text(bean_text, "SELECT account")

# a file on disk
{:ok, result} = Beancount.query_file("ledger.bean", "SELECT account")
```

## The result

A successful query returns a neutral, engine-independent
`Beancount.Query.Result`:

```elixir
%Beancount.Query.Result{
  columns: ["account", "balance"],
  rows: [["Assets:Bank", "5000 USD"], ["Income:Salary", "-5000 USD"]],
  raw: "account,balance\r\n...",
  status: :ok
}
```

Cells are kept as raw strings so the result stays backend-neutral. Convert to a
list of maps with `Beancount.Query.Result.to_maps/1`, or to an
`Explorer.DataFrame` via the optional bridge (see
[Reporting](reporting.md)).

## Errors

A query that fails (bad BQL, etc.) returns `{:error, %Beancount.Result{}}` with
normalized error details - the same shape as a failed `check`. A *missing*
`bean-query` binary raises `Beancount.Query.NotInstalledError`, keeping
environment problems separate from query errors.

## Configuration

```elixir
config :beancount_ex, bean_query_path: "bean-query"
```
