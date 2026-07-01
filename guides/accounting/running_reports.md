# Running reports

How to produce the reports an accounting UI needs, using `beancount_ex`. This
mirrors the reporting sections of
[Running Beancount and Generating Reports](https://beancount.github.io/docs/running_beancount_and_generating_reports/)
with the Elixir API.

## Engine configuration

Reports run through the configured engine:

```elixir
# Default: shells out to bean-query (requires pip install beancount beanquery)
config :beancount_ex, engine: Beancount.Engine.CLI

# Native: no bean-query required for canned reports
config :beancount_ex, engine: Beancount.Engine.Elixir
```

All examples below accept either a directive list or raw `.bean` text.

## Canned reports

```elixir
ledger = [...]  # or File.read!("ledger.bean")

{:ok, balances} = Beancount.balances(ledger)
{:ok, sheet} = Beancount.balance_sheet(ledger)
{:ok, income} = Beancount.income_statement(ledger)
{:ok, holdings} = Beancount.holdings(ledger)
{:ok, journal} = Beancount.journal(ledger, "Assets:Bank")
```

| Helper | Purpose |
|--------|---------|
| `balances/1` | Sum of positions per account |
| `balance_sheet/1` | Assets, Liabilities, Equity |
| `income_statement/1` | Income and Expenses |
| `holdings/1` | Units and cost for asset accounts |
| `journal/1` | Transaction history for one account |

## Result shape

```elixir
%Beancount.Query.Result{
  status: :ok,
  columns: ["account", "balance"],
  rows: [["Assets:Bank", "5000 USD"], ...]
}
```

Convert for JSON APIs:

```elixir
Beancount.Query.Result.to_maps(result)
# => [%{"account" => "Assets:Bank", "balance" => "5000 USD"}, ...]
```

## Custom BQL queries

```elixir
bql = """
SELECT date, flag, payee, narration, position, balance
WHERE account = "Assets:Bank"
ORDER BY date
"""

{:ok, result} = Beancount.query(ledger, bql)
```

Use `query_text/2` or `query_file/2` when the ledger is already on disk.

## Explorer DataFrames (optional)

Add `{:explorer, "~> 0.11"}` to your deps, then:

```elixir
{:ok, result} = Beancount.balances(ledger)
df = Beancount.Explorer.to_dataframe(result)
```

In Livebook, a `DataFrame` as the last cell renders as an interactive table.
Cast numeric columns with `Explorer.Series.cast/2` when needed.

## Wiring a UI

Typical Phoenix or LiveView flow:

1. Load ledger directives from your database or parse uploaded `.bean` text.
2. `Beancount.check/1` before save; show validation errors inline.
3. On dashboard mount, call `balance_sheet/1` and `income_statement/1`.
4. Pass `Query.Result.to_maps/1` to your template or charting library.

Example LiveView assign:

```elixir
{:ok, result} = Beancount.balances(socket.assigns.ledger)
assign(socket, :accounts, Beancount.Query.Result.to_maps(result))
```

## Validation without reports

When you only need pass/fail:

```elixir
case Beancount.check(ledger) do
  {:ok, _} -> :valid
  {:error, %{normalized: %{errors: errors}}} -> {:invalid, errors}
end
```

## Next

- [Cookbook](cookbook.md) - transaction patterns to feed into reports
- [Library: Querying](../querying.md) - BQL details and error handling
